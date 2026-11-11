# Espelha /usr/share/omarchy/default/bash/init para o Fish:
# mise (versionamento de ferramentas) + starship (prompt).
if status is-interactive; and command -v mise >/dev/null
    mise activate fish | source
end

if status is-interactive; and command -v starship >/dev/null
    starship init fish | source
end

# zoxide: mesmo `z`/`zi` do init bash do Omarchy, que o config.fish não espelhava
if status is-interactive; and command -v zoxide >/dev/null
    zoxide init fish | source
end

# Hermes Agent command
fish_add_path "$HOME/.local/bin"
