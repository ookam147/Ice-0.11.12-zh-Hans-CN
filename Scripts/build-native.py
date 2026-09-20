#!/usr/bin/env python3
"""Build a locally ad-hoc-signed Release app using Command Line Tools, without Xcode."""
import json
import pathlib
import platform
import plistlib
import shutil
import subprocess
import tempfile

from typecheck import ROOT, prepare_dependencies

OUTPUT = ROOT / "build/NativeLite-CLT-hover-fix"


def run(*args, log=None):
    if log is None:
        subprocess.run(args, cwd=ROOT, check=True)
    else:
        with log.open("w") as stream:
            result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode:
            print(log.read_text())
            raise subprocess.CalledProcessError(result.returncode, args)


def copy_assets(resources, temporary):
    """This catalog uses PNG images and the system accent color; no actool is needed."""
    catalog = ROOT / "Ice/Assets.xcassets"
    templates = []
    for image_set in sorted(catalog.rglob("*.imageset")):
        data = json.loads((image_set / "Contents.json").read_text())
        representations = [entry for entry in data["images"] if entry.get("filename")]
        if not representations:
            raise RuntimeError(f"No image representation in {image_set}")
        for index, entry in enumerate(representations):
            source = image_set / entry["filename"]
            if source.suffix.lower() != ".png":
                raise RuntimeError(f"Unsupported resource format: {source}")
            # Provide a base resource even for catalogs with only a 2x representation.
            if index == 0:
                shutil.copy2(source, resources / (image_set.stem + ".png"))
            if entry.get("scale") == "2x":
                shutil.copy2(source, resources / (image_set.stem + "@2x.png"))
        if data.get("properties", {}).get("template-rendering-intent") == "template":
            templates.append(image_set.stem)
    # Fail visibly if a future change introduces a custom color that needs actool.
    for color_set in catalog.rglob("*.colorset"):
        if color_set.stem == "DefaultLayoutBarColor":
            continue  # Removed screenshot/layout UI; this color is no longer referenced.
        data = json.loads((color_set / "Contents.json").read_text())
        if any("color" in entry for entry in data["colors"]):
            raise RuntimeError(f"Custom colors require an explicit native-resource implementation: {color_set}")
    iconset = temporary / "AppIcon.iconset"
    iconset.mkdir()
    for image in (catalog / "AppIcon.appiconset").glob("*.png"):
        shutil.copy2(image, iconset / image.name)
    run("iconutil", "-c", "icns", str(iconset), "-o", str(resources / "AppIcon.icns"))
    return templates


def main():
    checkout, framework_parent = prepare_dependencies()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    modules = OUTPUT / "modules"
    modules.mkdir(exist_ok=True)
    target = platform.machine() + "-apple-macosx14.0"
    run("xcrun", "swiftc", "-emit-library", "-static", "-emit-module", "-module-name", "AXSwift",
        "-parse-as-library", "-O", "-whole-module-optimization", "-target", target,
        *map(str, sorted((checkout / "Sources").glob("*.swift"))),
        "-emit-module-path", str(modules / "AXSwift.swiftmodule"),
        "-o", str(modules / "libAXSwift.a"), log=OUTPUT / "axswift-build.log")

    with tempfile.TemporaryDirectory(prefix="staging-", dir=OUTPUT) as directory:
        temporary = pathlib.Path(directory)
        app = temporary / "Ice Native Lite.app"
        contents = app / "Contents"
        for folder in ("MacOS", "Resources", "Frameworks"):
            (contents / folder).mkdir(parents=True)
        run("xcrun", "swiftc", "-O", "-whole-module-optimization", "-parse-as-library",
            "-module-name", "Ice", "-swift-version", "5", "-target", target,
            "-I", str(modules), "-L", str(modules), "-lAXSwift", "-F", str(framework_parent),
            "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
            "-Xlinker", "-dead_strip", *map(str, sorted((ROOT / "Ice").rglob("*.swift"))),
            "-o", str(contents / "MacOS/Ice"), log=OUTPUT / "compile.log")
        resources = contents / "Resources"
        shutil.copytree(ROOT / "Ice/Resources", resources, dirs_exist_ok=True)
        templates = copy_assets(resources, temporary)
        with (ROOT / "Ice/Info.plist").open("rb") as source:
            info = plistlib.load(source)
        info.update({
            "CFBundleExecutable": "Ice", "CFBundleName": "Ice Native Lite",
            "CFBundleDisplayName": "Ice Native Lite", "CFBundleIdentifier": "com.jordanbaird.Ice",
            "CFBundlePackageType": "APPL", "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleShortVersionString": "0.11.12", "CFBundleVersion": "1117",
            "CFBundleDevelopmentRegion": "en", "CFBundleIconFile": "AppIcon.icns",
            "LSMinimumSystemVersion": "14.0", "LSUIElement": True,
            "LSApplicationCategoryType": "public.app-category.utilities",
            "NSHighResolutionCapable": True, "NSPrincipalClass": "NSApplication",
            "NSHumanReadableCopyright": "Copyright © 2025 Jordan Baird",
            "IceTemplateImageNames": templates,
        })
        with (contents / "Info.plist").open("wb") as output:
            plistlib.dump(info, output)
        (contents / "PkgInfo").write_bytes(b"APPL????")
        framework = contents / "Frameworks/Sparkle.framework"
        run("ditto", str(framework_parent / "Sparkle.framework"), str(framework))
        # Sign nested code from the inside out; ad-hoc builds are local test artifacts.
        version = framework / "Versions/B"
        for nested in [version / "XPCServices/Downloader.xpc", version / "XPCServices/Installer.xpc",
                       version / "Autoupdate", version / "Updater.app", framework]:
            run("codesign", "--force", "--sign", "-", "--timestamp=none", str(nested))
        run("codesign", "--force", "--sign", "-", "--timestamp=none",
            "--entitlements", str(ROOT / "Ice/Ice.entitlements"), str(app))
        run("codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app))
        run("plutil", "-lint", str(contents / "Info.plist"))
        destination = OUTPUT / app.name
        if destination.exists():
            shutil.rmtree(destination)
        shutil.move(str(app), destination)
    archive = OUTPUT / "Ice-Native-Lite.zip"
    if archive.exists():
        archive.unlink()
    run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(destination), str(archive))
    print(f"Built {target}: {destination}\nArchive: {archive}")
    print("Locally ad-hoc signed; not notarized. Existing installed Ice was not replaced or launched.")


if __name__ == "__main__":
    main()
