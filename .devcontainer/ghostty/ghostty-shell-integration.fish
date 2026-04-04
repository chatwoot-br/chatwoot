# Ghostty shell integration for fish (self-contained, no host dependency)
# Sources the bundled integration script when running inside Ghostty.
# See: https://ghostty.org/docs/features/shell-integration

if test "$TERM" = xterm-ghostty
    # Set the resources dir to our bundled copy if not already set by Ghostty
    if not set -q GHOSTTY_RESOURCES_DIR
        set -gx GHOSTTY_RESOURCES_DIR /usr/share/ghostty
    end

    # Enable shell features if not already set by Ghostty
    if not set -q GHOSTTY_SHELL_FEATURES
        set -gx GHOSTTY_SHELL_FEATURES cursor,sudo,title
    end

    # Source the upstream integration script
    if test -f "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
        source "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
    end
end
