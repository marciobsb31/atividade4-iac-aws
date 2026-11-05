#!/usr/bin/env bash
# Testa o login WinRM (NTLM e Basic) na porta 5986 e mostra o erro real. Rode no Ubuntu/WSL:  bash scripts/test-winrm.sh
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source "$HOME/.venvs/atividade4/bin/activate"
IP=$(grep -oE 'ansible_host=[^ ]+' ansible/inventory.ini | head -1 | cut -d= -f2 | tr -d '\r\n ')
read -r -s -p "Senha Administrator: " ANSIBLE_PASSWORD; echo
export ANSIBLE_PASSWORD IP
for T in ntlm basic; do
  echo "--- transporte: $T (limite 40s) ---"
  TRANSPORT=$T timeout 40 python -u - <<'PY'
import os
from winrm.protocol import Protocol
ep = f"https://{os.environ['IP']}:5986/wsman"
print("endpoint:", ep)
try:
    p = Protocol(endpoint=ep, transport=os.environ["TRANSPORT"], username="Administrator",
                 password=os.environ["ANSIBLE_PASSWORD"], server_cert_validation="ignore",
                 operation_timeout_sec=15, read_timeout_sec=25)
    sid = p.open_shell()
    cid = p.run_command(sid, "hostname")
    out, err, code = p.get_command_output(sid, cid)
    p.cleanup_command(sid, cid); p.close_shell(sid)
    print("LOGIN OK | status", code, "| hostname:", out.decode().strip())
except Exception as e:
    print("FALHOU:", type(e).__name__, "-", str(e)[:300])
PY
  [ $? -eq 124 ] && echo "SEM RESPOSTA em 40s (travou)"
done
