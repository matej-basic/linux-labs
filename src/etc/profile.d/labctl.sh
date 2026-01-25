# shellcheck shell=bash
# Show active lab name in the prompt for interactive shells.

# Only adjust PS1 for interactive shells
case $- in
  *i*) ;;
  *) return ;;
esac

# Preserve the original prompt once; fall back if PS1 is empty or generic (-bash-4.4)
if [ -z "${LABCTL_BASE_PS1+x}" ]; then
  base_ps1="${PS1:-}"
  case "$base_ps1" in
    ""|-bash*|\\s-\\v\\\$*)
      LABCTL_BASE_PS1='[\u@\h \w]\$ '
      ;;
    *)
      LABCTL_BASE_PS1="$base_ps1"
      ;;
  esac
fi

_labctl_prompt() {
  local labfile="/opt/linux-labs/.current_lab"
  if [ -f "$labfile" ]; then
    local lab
    lab=$(cat "$labfile" 2>/dev/null)
    if [ -n "$lab" ]; then
      PS1="[LAB:${lab}] ${LABCTL_BASE_PS1}"
      return
    fi
  fi
  PS1="$LABCTL_BASE_PS1"
}

# Add hook once
case "$PROMPT_COMMAND" in
  *"_labctl_prompt"*) ;;
  "") PROMPT_COMMAND="_labctl_prompt" ;;
  *) PROMPT_COMMAND="${PROMPT_COMMAND};_labctl_prompt" ;;
esac
