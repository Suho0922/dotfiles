#!/usr/bin/env bash
set -Eeuo pipefail

# ==================================================#
# options
#   -c           install Miniconda
#   -f           skip backup step
#   -u <target>  reserved for update target
# usage:
#   bash install.sh
#   bash install.sh -c
#   bash install.sh -f -c
while getopts 'cfu:' flag; do
  case "${flag}" in
    c) install_conda='true' ;;
    f) forced='true' ;;
    u) update_target="${OPTARG}" ;;
    *) exit 1 ;;
  esac
done

install_conda="${install_conda:-false}"
forced="${forced:-false}"
update_target="${update_target:-}"

# ==================================================#
DOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"
ZSH_DIR="${HOME_DIR}/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-${ZSH_DIR}/custom}"

# ==================================================#
# helpers
log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '\n[warn] %s\n' "$*" >&2; }
die()  { printf '\n[error] %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

safe_clone() {
  local repo="$1"
  local dest="$2"

  if [ -d "$dest/.git" ] || [ -d "$dest" ]; then
    log "Already exists, skip clone: $dest"
  else
    git clone --depth 1 "$repo" "$dest"
  fi
}

link_file() {
  local src="$1"
  local dst="$2"
  ln -sfn "$src" "$dst"
  log "Linked: $dst -> $src"
}

backup_if_exists() {
  local target
  for target in "$@"; do
    local path="${HOME_DIR}/${target}"
    if [ -e "$path" ] || [ -L "$path" ]; then
      local backup="${path}.bak.$(date +%Y%m%d_%H%M%S)"
      mv "$path" "$backup"
      log "Backed up: $path -> $backup"
    fi
  done
}

append_line_if_missing() {
  local line="$1"
  local file="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  grep -Fqx "$line" "$file" || echo "$line" >> "$file"
}

# ==================================================#
# preflight
need_cmd git
need_cmd curl

if [ "$forced" != "true" ]; then
  backup_if_exists \
    ".Xmodmap" \
    ".vim" \
    ".vimrc" \
    ".tmux.conf" \
    ".aliases" \
    ".gitconfig" \
    ".condarc" \
    ".zshrc" \
    ".fzf"
fi

# ==================================================#
# dotfile symlinks
log "Link dotfiles"
link_file "${DOT_DIR}/Xmodmap"   "${HOME_DIR}/.Xmodmap"
link_file "${DOT_DIR}/vimrc"     "${HOME_DIR}/.vimrc"
link_file "${DOT_DIR}/tmux.conf" "${HOME_DIR}/.tmux.conf"
link_file "${DOT_DIR}/aliases"   "${HOME_DIR}/.aliases"
link_file "${DOT_DIR}/gitconfig" "${HOME_DIR}/.gitconfig"
link_file "${DOT_DIR}/condarc"   "${HOME_DIR}/.condarc"
link_file "${DOT_DIR}/zshrc"     "${HOME_DIR}/.zshrc"

# ==================================================#
# oh-my-zsh
log "Install Oh My Zsh if needed"
if [ ! -d "${ZSH_DIR}" ]; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "Oh My Zsh already installed"
fi

mkdir -p "${ZSH_CUSTOM}/plugins"
mkdir -p "${ZSH_DIR}/themes"

if [ -f "${DOT_DIR}/themes/mrtazz_custom.zsh-theme" ]; then
  link_file "${DOT_DIR}/themes/mrtazz_custom.zsh-theme" \
            "${ZSH_DIR}/themes/mrtazz_custom.zsh-theme"
fi

# ==================================================#
# zsh plugins
log "Install zsh plugins"
safe_clone "https://github.com/djui/alias-tips.git" \
           "${ZSH_CUSTOM}/plugins/alias-tips"

safe_clone "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
           "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

safe_clone "https://github.com/zsh-users/zsh-autosuggestions.git" \
           "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"

# ==================================================#
# fzf
log "Install fzf"
if [ ! -d "${HOME_DIR}/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME_DIR}/.fzf"
  "${HOME_DIR}/.fzf/install" --all
else
  log "fzf already installed"
fi

# ==================================================#
# vim setup
log "Install vim plugins"
mkdir -p "${HOME_DIR}/.vim/autoload" "${HOME_DIR}/.vim/bundle" "${HOME_DIR}/.vim/pack/tpope/start"

# colorschemes repo
if [ ! -d "${HOME_DIR}/.vim/colorschemes/.git" ]; then
  git clone --depth 1 https://github.com/flazz/vim-colorschemes.git "${HOME_DIR}/.vim/colorschemes"
else
  log "vim-colorschemes already installed"
fi

# pathogen
if [ ! -f "${HOME_DIR}/.vim/autoload/pathogen.vim" ]; then
  curl -fLo "${HOME_DIR}/.vim/autoload/pathogen.vim" --create-dirs https://tpo.pe/pathogen.vim
else
  log "pathogen already installed"
fi

safe_clone "https://github.com/preservim/nerdtree.git" \
           "${HOME_DIR}/.vim/bundle/nerdtree"

safe_clone "https://github.com/davidhalter/jedi-vim.git" \
           "${HOME_DIR}/.vim/bundle/jedi-vim"

safe_clone "https://github.com/vim-airline/vim-airline.git" \
           "${HOME_DIR}/.vim/bundle/vim-airline"

safe_clone "https://github.com/vim-airline/vim-airline-themes.git" \
           "${HOME_DIR}/.vim/bundle/vim-airline-themes"

safe_clone "https://github.com/nvie/vim-flake8.git" \
           "${HOME_DIR}/.vim/bundle/vim-flake8"

safe_clone "https://github.com/tpope/vim-commentary.git" \
           "${HOME_DIR}/.vim/pack/tpope/start/commentary"

safe_clone "https://github.com/ctrlpvim/ctrlp.vim.git" \
           "${HOME_DIR}/.vim/bundle/ctrlp.vim"

safe_clone "https://github.com/mhartington/oceanic-next.git" \
           "${HOME_DIR}/.vim/bundle/oceanic-next"

if command -v vim >/dev/null 2>&1; then
  vim -u NONE -c "silent! helptags ${HOME_DIR}/.vim/pack/tpope/start/commentary/doc" -c q || true
  vim -u NONE -c "silent! helptags ${HOME_DIR}/.vim/bundle/ctrlp.vim/doc" -c q || true
fi

# ==================================================#
# Miniconda
install_miniconda() {
  local arch installer url prefix tmp_installer

  arch="$(uname -m)"
  case "$arch" in
    x86_64)  installer="Miniconda3-latest-Linux-x86_64.sh" ;;
    aarch64|arm64) installer="Miniconda3-latest-Linux-aarch64.sh" ;;
    *)
      die "Unsupported architecture for Miniconda auto-install: $arch"
      ;;
  esac

  prefix="${HOME_DIR}/miniconda3"
  tmp_installer="/tmp/${installer}"
  url="https://repo.anaconda.com/miniconda/${installer}"

  if [ -x "${prefix}/bin/conda" ]; then
    log "Miniconda already exists at ${prefix}"
    return
  fi

  log "Download Miniconda: ${installer}"
  curl -fL "$url" -o "$tmp_installer"

  log "Install Miniconda to ${prefix}"
  bash "$tmp_installer" -b -p "$prefix"
  rm -f "$tmp_installer"

  # shell init is left to user profile or first manual 'conda init zsh'
  if [ -x "${prefix}/bin/conda" ]; then
    "${prefix}/bin/conda" init zsh || true
    "${prefix}/bin/conda" init bash || true
  fi
}

if [ "$install_conda" = "true" ]; then
  install_miniconda
fi

# ==================================================#
# set zsh as default shell
log "Set zsh as default shell if possible"
if command -v zsh >/dev/null 2>&1; then
  current_shell="$(getent passwd "$(whoami)" | cut -d: -f7 || true)"
  zsh_path="$(command -v zsh)"

  if [ "${current_shell}" != "${zsh_path}" ]; then
    if command -v chsh >/dev/null 2>&1; then
      warn "Changing login shell to ${zsh_path}"
      chsh -s "${zsh_path}" || warn "chsh failed. You may need to run: chsh -s ${zsh_path}"
    else
      warn "chsh not available. Run manually: chsh -s ${zsh_path}"
    fi
  else
    log "Default shell already set to zsh"
  fi
else
  warn "zsh is not installed. Install zsh first, then run: chsh -s \$(command -v zsh)"
fi

log "Done. Restart your shell or run: exec zsh"
