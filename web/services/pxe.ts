import { Fr } from '@aztec/aztec.js/fields';
import type { AztecNode } from '@aztec/aztec.js/node';
import { createAztecNodeClient } from '@aztec/aztec.js/node';
import { SPONSORED_FPC_SALT } from '@aztec/constants';
import { createStore } from '@aztec/kv-store/indexeddb';
import { SponsoredFPCContractArtifact } from '@aztec/noir-contracts.js/SponsoredFPC';
import { createPXE } from '@aztec/pxe/client/bundle';
import { getPXEConfig } from '@aztec/pxe/config';
import type { PXE } from '@aztec/pxe/server';
import { SponsoredFeePaymentMethod } from '@aztec/aztec.js/fee';
import { getContractInstanceFromInstantiationParams } from '@aztec/aztec.js/contracts';
import { getNodeUrl, isProverEnabled } from '../config';
import { log } from 'console';

export interface PXEInstance {
  pxe: PXE;
  aztecNode: AztecNode;
  getSponsoredFeePaymentMethod: () => Promise<SponsoredFeePaymentMethod>;
}

let pxeInstance: PXEInstance | null = null;
let initPromise: Promise<PXEInstance> | null = null;

async function getSponsoredFPCContract() {
  return await getContractInstanceFromInstantiationParams(
    SponsoredFPCContractArtifact,
    { salt: new Fr(SPONSORED_FPC_SALT) }
  );
}

async function initializePXE(): Promise<PXEInstance> {
  const nodeUrl = getNodeUrl();
  console.log('[PXE] Initializing PXE with node:', nodeUrl);

  const aztecNode = createAztecNodeClient(nodeUrl);

  // Get L1 contracts for network-specific database
  const l1Contracts = await aztecNode.getL1ContractAddresses();
  const storeName = 'battleships-pxe';

  // Create IndexedDB store for browser
  const pxeStore = await createStore(
    storeName,
    {
      dataDirectory: 'pxe',
      dataStoreMapSizeKb: 5e5, // 500MB
    }
  );

  const config = getPXEConfig();
  config.l1Contracts = l1Contracts;
  config.proverEnabled = isProverEnabled();

  const pxe = await createPXE(aztecNode, config, {
    store: pxeStore,
    useLogSuffix: false,
  });

  // Register SponsoredFPC contract for fee payments
  const sponsoredFPCInstance = await getSponsoredFPCContract();
  await pxe.registerContract({
    instance: sponsoredFPCInstance,
    artifact: SponsoredFPCContractArtifact,
  });

  const nodeInfo = await aztecNode.getNodeInfo();
  console.log('[PXE] Connected to Aztec node:', nodeInfo);

  // Cache sponsored fee payment method
  let cachedPaymentMethod: SponsoredFeePaymentMethod | null = null;

  return {
    pxe,
    aztecNode,
    getSponsoredFeePaymentMethod: async () => {
      if (!cachedPaymentMethod) {
        const contract = await getSponsoredFPCContract();
        cachedPaymentMethod = new SponsoredFeePaymentMethod(contract.address);
      }
      return cachedPaymentMethod;
    },
  };
}

export async function getPXE(): Promise<PXEInstance> {
  if (pxeInstance) {
    return pxeInstance;
  }

  if (initPromise) {
    return initPromise;
  }

  initPromise = initializePXE();
  try {
    pxeInstance = await initPromise;
    return pxeInstance;
  } finally {
    initPromise = null;
  }
}

export function isPXEInitialized(): boolean {
  return pxeInstance !== null;
}
