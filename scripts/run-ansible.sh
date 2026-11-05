#!/usr/bin/env bash
# Rode no Ubuntu/WSL, na raiz do repositório:  bash scripts/run-ansible.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VENV="$HOME/.venvs/atividade4"
[ -d "$VENV" ] || python3 -m venv "$VENV" || { echo "Instale: sudo apt install -y python3-venv python3-pip"; exit 1; }
# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -m pip install --quiet --upgrade pip
python -m pip install --quiet ansible "pywinrm>=0.4.3"
ansible-galaxy collection install -r ansible/requirements.yml

[ -f ansible/inventory.ini ] || { echo "Falta ansible/inventory.ini (copie do .example e ponha o IP da VM)"; exit 1; }

if [ -z "${ANSIBLE_PASSWORD:-}" ]; then
  read -r -s -p "Senha Administrator (aws ec2 get-password-data): " ANSIBLE_PASSWORD; echo
  export ANSIBLE_PASSWORD
fi

mkdir -p evidence
export ANSIBLE_NOCOLOR=1 ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i ansible/inventory.ini ansible/site.yml "$@" 2>&1 | tee evidence/ansible-playbook.log
