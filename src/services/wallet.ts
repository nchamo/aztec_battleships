import { EcdsaRAccountContract } from '@aztec/accounts/ecdsa';
import type { AccountWithSecretKey, Account } from '@aztec/aztec.js/account';
import { SignerlessAccount } from '@aztec/aztec.js/account';
import { AztecAddress } from '@aztec/aztec.js/addresses';
import { Fr } from '@aztec/aztec.js/fields';
import type { AztecNode } from '@aztec/aztec.js/node';
import { AccountManager } from '@aztec/aztec.js/wallet';
import { poseidon2Hash } from '@aztec/foundation/crypto/poseidon';
import type { PXE } from '@aztec/pxe/server';
import { BaseWallet } from '@aztec/wallet-sdk/base-wallet';
import type { PlayerSlot } from '../lib/types';
import { getPXE } from './pxe';

// Minimal wallet implementation for browser
class MinimalWallet extends BaseWallet {
  private readonly addressToAccount = new Map<string, AccountWithSecretKey>();

  constructor(pxe: PXE, aztecNode: AztecNode) {
    super(pxe, aztecNode);
  }

  public addAccount(account: AccountWithSecretKey) {
    this.addressToAccount.set(account.getAddress().toString(), account);
  }

  protected async getAccountFromAddress(address: AztecAddress): Promise<Account> {
    // Handle undefined/null address by returning the first registered account
    if (!address) {
      const accounts = Array.from(this.addressToAccount.values());
      if (accounts.length === 0) {
        throw new Error('No accounts registered in wallet');
      }
      return accounts[0];
    }

    if (address.equals(AztecAddress.ZERO)) {
      const chainInfo = await this.getChainInfo();
      return new SignerlessAccount(chainInfo);
    }

    const account = this.addressToAccount.get(address.toString());
    if (!account) {
      throw new Error(`Account not found for address: ${address.toString()}`);
    }
    return account;
  }

  async getAccounts(): Promise<{ alias: string; item: AztecAddress }[]> {
    return Array.from(this.addressToAccount.values()).map((acc) => ({
      alias: '',
      item: acc.getAddress(),
    }));
  }

  // Get the default account address for transactions
  getDefaultAddress(): AztecAddress | undefined {
    const accounts = Array.from(this.addressToAccount.values());
    return accounts.length > 0 ? accounts[0].getAddress() : undefined;
  }
}

// Storage keys for credentials per player slot
const getStorageKey = (slot: PlayerSlot) => `battleships-account-${slot}`;

interface StoredCredentials {
  secretKey: string;
  salt: string;
  signingKey: string;
}

// Generate deterministic credentials from player slot
async function generateCredentials(slot: PlayerSlot): Promise<{
  secretKey: Fr;
  salt: Fr;
  signingKey: Buffer;
}> {
  // Check localStorage first
  const storageKey = getStorageKey(slot);
  const stored = localStorage.getItem(storageKey);

  if (stored) {
    const creds: StoredCredentials = JSON.parse(stored);
    return {
      secretKey: Fr.fromString(creds.secretKey),
      salt: Fr.fromString(creds.salt),
      signingKey: Buffer.from(creds.signingKey, 'hex'),
    };
  }

  // Generate new credentials based on slot
  const secretKey = await poseidon2Hash([
    Fr.fromBufferReduce(Buffer.from(slot.padEnd(32, '#'), 'utf8')),
  ]);

  const salt = Fr.fromString(slot === 'player1' ? '1' : '2');
  const signingKey = Buffer.from(secretKey.toBuffer().subarray(0, 32));

  // Store credentials
  const toStore: StoredCredentials = {
    secretKey: secretKey.toString(),
    salt: salt.toString(),
    signingKey: signingKey.toString('hex'),
  };
  localStorage.setItem(storageKey, JSON.stringify(toStore));

  return { secretKey, salt, signingKey };
}

export interface WalletInstance {
  wallet: MinimalWallet;
  account: AccountWithSecretKey;
  address: AztecAddress;
}

export type WalletLoadingStatus = 'loading_wallet' | 'deploying_account';

export async function createOrLoadWallet(
  slot: PlayerSlot,
  onStatusChange?: (status: WalletLoadingStatus) => void
): Promise<WalletInstance> {
  console.log(`[Wallet] Creating/loading wallet for ${slot}...`);
  onStatusChange?.('loading_wallet');

  const { pxe, aztecNode, getSponsoredFeePaymentMethod } = await getPXE();
  const { secretKey, salt, signingKey } = await generateCredentials(slot);

  const wallet = new MinimalWallet(pxe, aztecNode);
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

  // Register the contract with PXE
  await wallet.registerContract(instance, artifact, manager.getSecretKey());
  wallet.addAccount(account);

  const address = account.getAddress();
  console.log(`[Wallet] Account address: ${address.toString()}`);

  // Check if account is deployed
  const metadata = await wallet.getContractMetadata(address);

  if (!metadata.isContractInitialized) {
    console.log('[Wallet] Deploying account contract...');
    onStatusChange?.('deploying_account');

    const paymentMethod = await getSponsoredFeePaymentMethod();
    const deployMethod = await manager.getDeployMethod();

    await deployMethod
      .send({
        from: AztecAddress.ZERO,
        contractAddressSalt: salt,
        fee: { paymentMethod },
        universalDeploy: true,
        skipClassRegistration: true,
        skipPublicDeployment: true,
      })
      .wait({ timeout: 300 });

    console.log('[Wallet] Account deployed successfully');
  } else {
    console.log('[Wallet] Account already deployed');
  }

  return { wallet, account, address };
}
