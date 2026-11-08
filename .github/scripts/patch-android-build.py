#!/usr/bin/env python3
"""Patches the Flutter-generated android/app/build.gradle after
`flutter create` so the project ships with the config
flutter_local_notifications + local_auth require: Java 11, core
library desugaring and minSdkVersion 23.

Idempotent — running the script twice does not duplicate edits.
"""
from __future__ import annotations
import pathlib
import re
import sys


def main() -> int:
    gradle = pathlib.Path("android/app/build.gradle")
    if not gradle.exists():
        print("build.gradle not found", file=sys.stderr)
        return 1
    src = gradle.read_text()

    src = re.sub(
        r"minSdkVersion\s+(?:flutter\.minSdkVersion|\d+)",
        "minSdkVersion 23",
        src,
    )

    if "coreLibraryDesugaringEnabled" not in src:
        src = src.replace(
            "android {",
            (
                "android {\n"
                "    compileOptions {\n"
                "        coreLibraryDesugaringEnabled true\n"
                "        sourceCompatibility JavaVersion.VERSION_11\n"
                "        targetCompatibility JavaVersion.VERSION_11\n"
                "    }\n"
                "    kotlinOptions {\n"
                "        jvmTarget = '11'\n"
                "    }\n"
            ),
            1,
        )

    if "com.android.tools:desugar_jdk_libs" not in src:
        src = re.sub(
            r"dependencies\s*\{",
            (
                "dependencies {\n"
                "    coreLibraryDesugaring "
                "'com.android.tools:desugar_jdk_libs:2.0.4'"
            ),
            src,
            count=1,
        )

    gradle.write_text(src)
    print(f"Patched {gradle}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
