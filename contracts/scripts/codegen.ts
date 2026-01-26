// Run with: tsx scripts/codegen.ts
// This script compiles the Battleships contract and generates TypeScript wrappers for the web app

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

// Paths relative to contracts/ directory
const CONTRACT_DIR = process.cwd();
const WEB_DIR = path.join(CONTRACT_DIR, '..', 'web');
const ARTIFACTS_OUTPUT_DIR = path.join(WEB_DIR, 'artifacts');
const TARGET_OUTPUT_DIR = path.join(WEB_DIR, 'target');

/**
 * Run a command and return success status
 */
function runCommand(cmd: string): boolean {
  const res = spawnSync(cmd, { stdio: 'inherit', shell: '/bin/bash', cwd: CONTRACT_DIR });
  return res.status === 0;
}

/**
 * Ensure a directory exists
 */
function ensureDir(p: string): void {
  fs.mkdirSync(p, { recursive: true });
}

/**
 * Copy JSON files from source to target directory
 */
function copyJsonFiles(sourceDir: string, targetDir: string): number {
  if (!fs.existsSync(sourceDir)) {
    console.log(`⚠️ Source directory ${sourceDir} does not exist`);
    return 0;
  }

  ensureDir(targetDir);
  const files = fs.readdirSync(sourceDir).filter(f => f.endsWith('.json'));

  for (const file of files) {
    fs.copyFileSync(path.join(sourceDir, file), path.join(targetDir, file));
    console.log(`   ✅ Copied ${file}`);
  }

  return files.length;
}

/**
 * Generate TypeScript wrapper using aztec codegen and fix import paths
 */
function generateTypeScriptWrapper(): boolean {
  // Use aztec codegen to generate the wrapper
  const targetDir = path.join(CONTRACT_DIR, 'target');
  const cmd = `aztec codegen "${targetDir}" --outdir "${ARTIFACTS_OUTPUT_DIR}" -f`;

  console.log(`   Running: aztec codegen...`);
  if (!runCommand(cmd)) {
    return false;
  }

  // Fix the import path in generated file
  const wrapperPath = path.join(ARTIFACTS_OUTPUT_DIR, 'Battleships.ts');
  if (fs.existsSync(wrapperPath)) {
    let content = fs.readFileSync(wrapperPath, 'utf-8');

    // Replace the generated import path with relative path to ../target/
    // The generated file has paths like:
    //   '../../contracts/target/battleships-Battleships.json' or
    //   '../../Users/.../contracts/target/battleships-Battleships.json'
    // We want: '../target/battleships-Battleships.json' (since we copy JSON to web/target/)
    content = content.replace(
      /from ['"]\.\.\/[^'"]*battleships-Battleships\.json['"]/,
      "from '../target/battleships-Battleships.json'"
    );

    fs.writeFileSync(wrapperPath, content);
    console.log(`   ✅ Generated and fixed TypeScript wrapper: ${wrapperPath}`);
  }

  return true;
}

async function main() {
  console.log(`
╔════════════════════════════════════════════════════════════════╗
║           BATTLESHIPS CONTRACT CODEGEN                         ║
╚════════════════════════════════════════════════════════════════╝
`);

  // Check we're in the contracts directory
  if (!fs.existsSync(path.join(CONTRACT_DIR, 'Nargo.toml'))) {
    console.error('❌ Error: Must be run from the contracts directory');
    process.exit(1);
  }

  // Compile contract
  console.log('🔨 Compiling contract...');
  if (!runCommand('aztec compile')) {
    console.error('❌ Failed to compile contract');
    console.error('   Make sure aztec is installed and in PATH: curl -s install.aztec.network | bash');
    process.exit(1);
  }
  console.log('✅ Contract compiled successfully\n');

  // Copy artifacts to web/target
  console.log('📁 Copying artifacts to web/target/...');
  ensureDir(ARTIFACTS_OUTPUT_DIR);
  ensureDir(TARGET_OUTPUT_DIR);

  const targetDir = path.join(CONTRACT_DIR, 'target');
  const copiedCount = copyJsonFiles(targetDir, TARGET_OUTPUT_DIR);
  console.log(`   📊 Copied ${copiedCount} JSON files\n`);

  // Generate TypeScript wrapper using aztec codegen
  console.log('📝 Generating TypeScript wrapper (using aztec codegen)...');
  if (!generateTypeScriptWrapper()) {
    console.error('❌ Failed to generate TypeScript wrapper');
    process.exit(1);
  }

  console.log('\n🎉 Codegen complete!');
}

main().catch((error) => {
  console.error('❌ Codegen failed:', error);
  process.exit(1);
});
