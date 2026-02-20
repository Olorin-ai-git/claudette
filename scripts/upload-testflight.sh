#!/bin/bash
# Promote Claudette build - archive and upload to App Store Connect

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Promoting Claudette to TestFlight${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

TEAM_ID="963B7732N5"
SCHEME="Claudette"
PROJECT="Claudette.xcodeproj"
ARCHIVE_PATH="/tmp/Claudette.xcarchive"
EXPORT_PATH="/tmp/ClaudetteExport"

# Resolve packages
echo -e "${BLUE}Resolving Swift packages...${NC}"
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -resolvePackageDependencies \
  -quiet

echo -e "${GREEN}Packages resolved${NC}"

# Archive
echo -e "${BLUE}Archiving Claudette...${NC}"
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  SWIFT_STRICT_CONCURRENCY=minimal \
  -quiet

echo -e "${GREEN}Archive succeeded${NC}"

# Create ExportOptions
cat > /tmp/ClaudetteExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>963B7732N5</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>uploadBitcode</key><false/>
  <key>manageAppVersionAndBuildNumber</key><true/>
</dict>
</plist>
EOF

# Export and upload
echo -e "${BLUE}Uploading to App Store Connect...${NC}"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist /tmp/ClaudetteExportOptions.plist \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

echo -e "${GREEN}Upload succeeded${NC}"

# Cleanup
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" /tmp/ClaudetteExportOptions.plist

echo -e "${GREEN}Claudette is now processing in App Store Connect${NC}"
echo -e "${BLUE}Check: https://appstoreconnect.apple.com/apps${NC}"
