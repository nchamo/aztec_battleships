import 'dotenv/config';
import { EcdsaRAccountContract } from '@aztec/accounts/ecdsa';
import {
  type AccountWithSecretKey,
  type Account,
  SignerlessAccount,
} from '@aztec/aztec.js/account';
import { AztecAddress } from '@aztec/aztec.js/addresses';
import {
  getContractInstanceFromInstantiationParams,
  DeployMethod,
  Contract,
  type DeployOptions,
} from '@aztec/aztec.js/contracts';
import { SponsoredFeePaymentMethod } from '@aztec/aztec.js/fee';
import { Fr } from '@aztec/aztec.js/fields';
import { PublicKeys } from '@aztec/aztec.js/keys';
import { createAztecNodeClient, type AztecNode } from '@aztec/aztec.js/node';
import { AccountManager, type Wallet } from '@aztec/aztec.js/wallet';
import { SPONSORED_FPC_SALT } from '@aztec/constants';
import { poseidon2Hash } from '@aztec/foundation/crypto/poseidon';
import { createStore } from '@aztec/kv-store/lmdb';
import { SponsoredFPCContractArtifact } from '@aztec/noir-contracts.js/SponsoredFPC';
import { getPXEConfig } from '@aztec/pxe/config';
import type { PXE } from '@aztec/pxe/server';
import { createPXE } from '@aztec/pxe/server';
import { BaseWallet } from '@aztec/wallet-sdk/base-wallet';
import fs from 'fs';
import path from 'path';
import { BattleshipsContractArtifact } from '../../web/artifacts/Battleships.js';

class MinimalWallet extends BaseWallet {
  private readonly addressToAccount = new Map<string, AccountWithSecretKey>();

  constructor(pxe: PXE, aztecNode: AztecNode) {
    super(pxe, aztecNode);
  }

  public addAccount(account: AccountWithSecretKey) {
    this.addressToAccount.set(account.getAddress().toString(), account);
  }

  protected async getAccountFromAddress(
    address: AztecAddress
  ): Promise<Account> {
    let account: Account | undefined;
    if (address.equals(AztecAddress.ZERO)) {
      const chainInfo = await this.getChainInfo();
      account = new SignerlessAccount(chainInfo);
    } else {
      account = this.addressToAccount.get(address.toString());
    }

    if (!account)
      throw new Error(
        `Account not found in wallet for address: ${address.toString()}`
      );
    return account;
  }

  async getAccounts(): Promise<{ alias: string; item: AztecAddress }[]> {
    return Array.from(this.addressToAccount.values()).map((acc) => ({
      alias: '',
      item: acc.getAddress(),
    }));
  }
}

// Parse command line arguments
const parseArgs = (): { network: string } => {
  const args = process.argv.slice(2);
  const networkIndex = args.findIndex(
    (arg) => arg === '--network' || arg === '-n'
  );

  if (networkIndex !== -1 && args[networkIndex + 1]) {
    const network = args[networkIndex + 1];
    if (network !== 'sandbox') {
      console.error(
        `Invalid network: ${network}. Currently only 'sandbox' is supported`
      );
      process.exit(1);
    }
    return { network };
  }

  return { network: 'sandbox' };
};

const { network: NETWORK } = parseArgs();

// Environment variable overrides
const AZTEC_NODE_URL = process.env.VITE_AZTEC_NODE_URL || 'http://localhost:8080';
const PROVER_ENABLED =
  process.env.VITE_PROVER_ENABLED === 'true' ? true : false;

const DEPLOY_TIMEOUT = 960;
const PXE_STORE_DIR = path.join(import.meta.dirname, '.store');

async function setupPXE() {
  console.log(`\n🔧 Setting up PXE for ${NETWORK}...`);
  console.log(`   Node URL: ${AZTEC_NODE_URL}`);
  console.log(`   Prover: ${PROVER_ENABLED ? 'enabled' : 'disabled'}\n`);

  const aztecNode = createAztecNodeClient(AZTEC_NODE_URL);

  fs.rmSync(PXE_STORE_DIR, { recursive: true, force: true });

  const store = await createStore('pxe', {
    dataDirectory: PXE_STORE_DIR,
    dataStoreMapSizeKb: 1e6,
  });

  const config = {
    ...getPXEConfig(),
    proverEnabled: PROVER_ENABLED,
  };

  const pxe = await createPXE(aztecNode, config, {
    store,
    useLogSuffix: true,
  });

  return { pxe, aztecNode };
}

async function getSponsoredFPCContract() {
  const instance = await getContractInstanceFromInstantiationParams(
    SponsoredFPCContractArtifact,
    {
      salt: new Fr(SPONSORED_FPC_SALT),
    }
  );

  return instance;
}

const getSponsoredFeePaymentMethod = async () => {
  const sponsoredPFCContract = await getSponsoredFPCContract();
  return new SponsoredFeePaymentMethod(sponsoredPFCContract.address);
};

// These credentials could also be randomly generated, but we use a fixed one for testing purposes
async function getDefaultCredentials() {
  const holaSecretKey = await poseidon2Hash([
    Fr.fromBufferReduce(Buffer.from('hola'.padEnd(32, '#'), 'utf8')),
  ]);
  return {
    salt: new Fr(1337n),
    secretKey: holaSecretKey,
    signingKey: Buffer.alloc(32, holaSecretKey.toBuffer()),
  };
}

async function generateCredentials() {
  if (process.env.VITE_EMBEDDED_ACCOUNT_SECRET_PHRASE) {
    // If we have a secret phrase, we use it to generate the credentials
    const secretKey = await poseidon2Hash([
      Fr.fromBufferReduce(
        Buffer.from(
          process.env.VITE_EMBEDDED_ACCOUNT_SECRET_PHRASE.padEnd(32, '#'),
          'utf8'
        )
      ),
    ]);
    return {
      secretKey,
      salt: Fr.fromString(process.env.VITE_COMMON_SALT || '1337'),
      signingKey: Buffer.from(secretKey.toBuffer().subarray(0, 32)),
    };
  } else if (
    process.env.VITE_EMBEDDED_ACCOUNT_SECRET_KEY &&
    process.env.VITE_COMMON_SALT
  ) {
    // If we have a secret key and salt, we use them to generate the credentials
    return {
      salt: Fr.fromString(process.env.VITE_COMMON_SALT),
      secretKey: Fr.fromString(process.env.VITE_EMBEDDED_ACCOUNT_SECRET_KEY),
      signingKey: Buffer.from(
        process.env.VITE_EMBEDDED_ACCOUNT_SIGNING_KEY!,
        'hex'
      ),
    };
  } else {
    console.log('Generating default credentials...');
    // Otherwise, we generate default credentials
    return getDefaultCredentials();
  }
}

async function createAccount(pxe: PXE, node: AztecNode) {
  console.log('👤 Setting up deployer account...');

  const { secretKey, salt, signingKey } = await generateCredentials();
  console.log('   Credentials generated:');
  console.log(`   - Secret Key: ${secretKey.toString().slice(0, 20)}...`);
  console.log(`   - Salt: ${salt.toString().slice(0, 20)}...`);

  const wallet = new MinimalWallet(pxe, node);
  const accountContract = new EcdsaRAccountContract(signingKey);
  const manager = await AccountManager.create(
    wallet,
    secretKey,
    accountContract,
    salt
  );
  const account = await manager.getAccount();
  const instance = manager.getInstance();
  const artifact = await manager.getAccountContract().getContractArtifact();

  await wallet.registerContract(instance, artifact, manager.getSecretKey());
  wallet.addAccount(account);

  console.log(`   ✅ Account created: ${account.getAddress().toString()}`);

  const metadata = await wallet.getContractMetadata(account.getAddress());
  if (!metadata.isContractInitialized) {
    console.log('   📦 Deploying account contract...');
    const sponsoredFeePaymentMethod = await getSponsoredFeePaymentMethod();
    const deployOpts = {
      from: AztecAddress.ZERO,
      contractAddressSalt: salt,
      fee: {
        paymentMethod: sponsoredFeePaymentMethod,
      },
      universalDeploy: true,
      skipClassRegistration: true,
      skipPublicDeployment: true,
    };
    const deployMethod = await manager.getDeployMethod();
    await deployMethod.send(deployOpts).wait({ timeout: DEPLOY_TIMEOUT });
    console.log('   ✅ Account deployed');
  } else {
    console.log('   ✅ Account already deployed');
  }

  return {
    wallet,
    account,
  };
}

async function deployBattleshipsContract(
  pxe: PXE,
  deployer: Wallet,
  options: DeployOptions
) {
  console.log('📦 Deploying Battleships contract...');

  const salt = Fr.fromString(process.env.VITE_COMMON_SALT || '1337');

  const deployMethod = new DeployMethod(
    PublicKeys.default(),
    deployer,
    BattleshipsContractArtifact,
    (instance, wallet) =>
      Contract.at(instance.address, BattleshipsContractArtifact, wallet)
  );

  const receipt = await deployMethod
    .send({
      ...options,
      contractAddressSalt: salt,
      fee: {
        paymentMethod: await getSponsoredFeePaymentMethod(),
      },
      universalDeploy: true,
      skipInitialization: true,
    })
    .wait({ timeout: DEPLOY_TIMEOUT });

  console.log(`   Mined at block: ${receipt.blockNumber}`);
  console.log(`   Tx hash: ${receipt.txHash}`);

  const contract = receipt.contract;
  console.log(`   ✅ Battleships deployed at: ${contract.address.toString()}`);

  // Contract is already registered during deployment via DeployMethod
  return {
    instance: null,
    address: contract.address.toString(),
    salt: salt.toString(),
  };
}

interface DeploymentInfo {
  battleshipsContract: {
    address: string;
    salt: string;
  };
  deployer: string;
}

async function writeDeploymentConfig(
  network: string,
  deploymentInfo: DeploymentInfo
) {
  const configDir = path.join(import.meta.dirname, `../../web/config/deployments`);
  const configFilePath = path.join(configDir, `${network}.json`);

  // Ensure directory exists
  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
  }

  const config = {
    network,
    nodeUrl: AZTEC_NODE_URL,
    battleshipsContract: {
      address: deploymentInfo.battleshipsContract.address,
      salt: deploymentInfo.battleshipsContract.salt,
    },
    deployer: deploymentInfo.deployer,
    proverEnabled: PROVER_ENABLED,
    deployedAt: new Date().toISOString(),
  };

  fs.writeFileSync(configFilePath, JSON.stringify(config, null, 2) + '\n');

  console.log('\nDeployment successful');
  console.log(`- Network:     ${network}`);
  console.log(`- Config:      web/config/deployments/${network}.json`);
  console.log(`- Battleships: ${deploymentInfo.battleshipsContract.address}`);
  console.log(`- Deployer:    ${deploymentInfo.deployer}\n`);
}

async function createAccountAndDeployContract() {
  console.log(`
╔════════════════════════════════════════════════════════════════╗
║           BATTLESHIPS CONTRACT DEPLOYMENT                      ║
║           Network: ${NETWORK.padEnd(42)}║
╚════════════════════════════════════════════════════════════════╝
`);

  try {
    const { pxe, aztecNode } = await setupPXE();

    // Register the SponsoredFPC contract (for sponsored fee payments)
    await pxe.registerContract({
      instance: await getSponsoredFPCContract(),
      artifact: SponsoredFPCContractArtifact,
    });

    // Create a new account
    const { wallet, account } = await createAccount(pxe, aztecNode);

    const deployOptions: DeployOptions = {
      from: account.getAddress(),
    };

    // Deploy the Battleships contract
    const battleshipsDeploymentInfo = await deployBattleshipsContract(
      pxe,
      wallet,
      deployOptions
    );

    // Save the deployment info to JSON config file
    await writeDeploymentConfig(NETWORK, {
      battleshipsContract: {
        address: battleshipsDeploymentInfo.address,
        salt: battleshipsDeploymentInfo.salt,
      },
      deployer: account.getAddress().toString(),
    });
  } finally {
    // Always clean up the PXE store, even on failure
    fs.rmSync(PXE_STORE_DIR, { recursive: true, force: true });
  }
}

createAccountAndDeployContract().catch((error) => {
  console.error('❌ Deployment failed:', error);
  process.exit(1);
});

export { createAccountAndDeployContract };
