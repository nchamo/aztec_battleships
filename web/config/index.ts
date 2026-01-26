export interface DeploymentConfig {
  network: string;
  nodeUrl: string;
  battleshipsContract: {
    address: string;
    salt: string;
  };
  deployer: string;
  proverEnabled: boolean;
  deployedAt: string;
}

// Load deployment configuration for sandbox network
export async function loadDeploymentConfig(): Promise<DeploymentConfig> {
  try {
    const config = await import('./deployments/sandbox.json');
    return config.default as DeploymentConfig;
  } catch (error) {
    throw new Error(
      'Deployment config not found. Run `yarn deploy-contracts` first.'
    );
  }
}

// Get node URL from environment or config
export function getNodeUrl(): string {
  return import.meta.env.VITE_AZTEC_NODE_URL || 'http://localhost:8080';
}

// Check if prover is enabled
export function isProverEnabled(): boolean {
  return import.meta.env.VITE_PROVER_ENABLED === 'true';
}
