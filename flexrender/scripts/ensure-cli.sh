#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
CLI_VERSION_FILE="$PLUGIN_DIR/cli-version.json"

# Parse cli-version.json (no jq dependency — use grep+sed)
MIN_VERSION=$(grep '"minVersion"' "$CLI_VERSION_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
REC_VERSION=$(grep '"recommendedVersion"' "$CLI_VERSION_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
URL_PATTERN=$(grep '"releaseUrlPattern"' "$CLI_VERSION_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')

# Semantic version comparison: returns 0 if $1 >= $2
version_gte() {
    local IFS=.
    local i a=($1) b=($2)
    for ((i=0; i<${#b[@]}; i++)); do
        [[ ${a[i]:-0} -gt ${b[i]:-0} ]] && return 0
        [[ ${a[i]:-0} -lt ${b[i]:-0} ]] && return 1
    done
    return 0
}

# Detect platform RID
detect_rid() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Darwin)
            case "$arch" in
                arm64) echo "osx-arm64" ;;
                x86_64) echo "osx-x64" ;;
                *) echo "osx-x64" ;;
            esac ;;
        Linux)
            case "$arch" in
                aarch64|arm64) echo "linux-arm64" ;;
                x86_64) echo "linux-x64" ;;
                *) echo "linux-x64" ;;
            esac ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "win-x64" ;;
        *)
            echo "linux-x64" ;;
    esac
}

# Install via dotnet tool
install_dotnet_tool() {
    if command -v dotnet &>/dev/null; then
        echo "Installing flexrender-cli v$REC_VERSION via dotnet tool..."
        if dotnet tool install -g flexrender-cli --version "$REC_VERSION" 2>/dev/null; then
            return 0
        fi
        if dotnet tool update -g flexrender-cli --version "$REC_VERSION" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Install via binary download
install_binary() {
    local rid url install_dir
    rid="$(detect_rid)"
    url="${URL_PATTERN//\{version\}/$REC_VERSION}"
    url="${url//\{rid\}/$rid}"
    install_dir="$HOME/.local/bin"

    echo "Downloading flexrender v$REC_VERSION for $rid..."
    mkdir -p "$install_dir"

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" | tar -xz -C "$install_dir"
    elif command -v wget &>/dev/null; then
        wget -qO- "$url" | tar -xz -C "$install_dir"
    else
        echo "FlexRender CLI not installed: neither curl nor wget found." >&2
        echo "  Install manually: https://github.com/RoboNET/FlexRender/releases" >&2
        return 1
    fi

    chmod +x "$install_dir/flexrender" 2>/dev/null || true
    echo "Installed flexrender to $install_dir/flexrender"

    if ! echo "$PATH" | tr ':' '\n' | grep -q "^$install_dir$"; then
        echo "$install_dir is not in PATH. Add to your shell profile:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

main() {
    local current_version=""

    if command -v flexrender &>/dev/null; then
        current_version=$(flexrender --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
    fi

    if [[ -z "$current_version" ]]; then
        echo "FlexRender CLI not found. Installing..."
        install_dotnet_tool || install_binary || true
        return
    fi

    if ! version_gte "$current_version" "$MIN_VERSION"; then
        echo "FlexRender CLI v$current_version is below minimum required v$MIN_VERSION"
        echo "  Updating..."
        install_dotnet_tool || install_binary || true
        return
    fi

    if ! version_gte "$current_version" "$REC_VERSION"; then
        echo "FlexRender CLI v$current_version available, recommended v$REC_VERSION"
        echo "  Update: dotnet tool update -g flexrender-cli --version $REC_VERSION"
    fi
}

main
