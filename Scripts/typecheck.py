#!/usr/bin/env python3
"""Type-check Release sources with CLT; this does not build/sign an application bundle."""
import hashlib
import pathlib
import platform
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORK = ROOT / "build/validation"
AX_REVISION = "81dcc36aced905d6464cc25e35f8d13184bbf21c"
SPARKLE_SHA256 = "eb3814726816ca2f09334ce562fff1b2cd0f7c16dd4e283256081f307accb9c4"


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def prepare_dependencies():
    WORK.mkdir(parents=True, exist_ok=True)
    checkout = WORK / "AXSwift"
    if not checkout.exists():
        run("git", "clone", "--quiet", "--depth", "1", "--branch", "0.3.2",
            "https://github.com/tmandry/AXSwift.git", str(checkout))
    revision = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    if revision != AX_REVISION:
        raise RuntimeError("AXSwift checkout does not match the project lockfile")

    archive = WORK / "Sparkle.zip"
    if not archive.exists():
        run("curl", "-fL", "--retry", "2", "--max-time", "90",
            "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-for-Swift-Package-Manager.zip",
            "-o", str(archive))
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SPARKLE_SHA256:
        raise RuntimeError("Sparkle archive checksum mismatch")
    framework_parent = WORK / "Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
    if not (framework_parent / "Sparkle.framework/Modules/module.modulemap").exists():
        # ditto preserves the framework's symlinks, unlike zipfile.extractall.
        run("ditto", "-x", "-k", str(archive), str(WORK / "Sparkle"))

    return checkout, framework_parent


def main():
    checkout, framework_parent = prepare_dependencies()
    target = platform.machine() + "-apple-macosx14.0"
    run("xcrun", "swiftc", "-emit-module", "-module-name", "AXSwift", "-parse-as-library",
        "-target", target, *map(str, sorted((checkout / "Sources").glob("*.swift"))),
        "-emit-module-path", str(WORK / "AXSwift.swiftmodule"))
    command = ["xcrun", "swiftc", "-typecheck", "-module-name", "Ice", "-swift-version", "5",
               "-target", target, "-I", str(WORK), "-F", str(framework_parent),
               *map(str, sorted((ROOT / "Ice").rglob("*.swift")))]
    log = WORK / "typecheck.log"
    with log.open("w") as output:
        result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    print(log.read_text())
    if result.returncode:
        raise SystemExit(result.returncode)
    print("All Release Swift sources passed type checking (not an Xcode build).")


if __name__ == "__main__":
    main()
