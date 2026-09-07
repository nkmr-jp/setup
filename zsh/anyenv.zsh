# Generate the anyenv init cache.
#
# `anyenv init -` takes 550ms because it starts a process for each environment, but
# its output stays unchanged until environments or versions change. init.zsh caches this function's output.
#
# Removed from the output:
#   jenv refresh-plugins is a maintenance command that recreates plugin symlinks.
#     It only does real work after jenv itself changes (by comparing jenv.version with the current version),
#     yet costs 70ms on every shell startup. The cache is rebuilt when jenv changes
#     ($ANYENV_ROOT/envs/*/libexec is a dependency), so run it once here
#     when rebuilding and remove it from the per-startup output.
#     If plugin links seem stale after updating jenv, run `jenv refresh-plugins --force`.
_zsh_gen_anyenv_init() {
    local jenv="${ANYENV_ROOT:-$HOME/.anyenv}/envs/jenv/bin/jenv"
    [[ -x $jenv ]] && "$jenv" refresh-plugins >/dev/null 2>&1
    anyenv init - --no-rehash zsh | grep -v '^jenv refresh-plugins$'
}
