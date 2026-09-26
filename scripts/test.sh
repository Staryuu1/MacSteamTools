#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests
swiftc -module-cache-path "$PWD/.build/clang-cache" Sources/MacSteamTools/Installer.swift Sources/MacSteamTools/Catalog.swift Tests/MacSteamToolsTests/InstallerTests.swift Tests/MacSteamToolsTests/CatalogTests.swift -o .build/tests/InstallerTests
.build/tests/InstallerTests
