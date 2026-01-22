/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_AZTEC_NODE_URL: string;
  readonly VITE_PROVER_ENABLED: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
