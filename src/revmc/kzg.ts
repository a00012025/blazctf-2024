import cKzg from "c-kzg";
import { setupKzg } from "viem";
import { mainnetTrustedSetupPath } from "viem/node";

console.log(mainnetTrustedSetupPath);
export const kzg = setupKzg(
  {
    loadTrustedSetup: (path: string) => {
      console.log("loading", path);
      path = path.replace("/_esm", "");
      return cKzg.loadTrustedSetup(0, path);
    },
    blobToKzgCommitment: cKzg.blobToKzgCommitment,
    computeBlobKzgProof: cKzg.computeBlobKzgProof,
  },
  mainnetTrustedSetupPath
);
