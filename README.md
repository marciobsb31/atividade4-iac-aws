# Atividade 4 — Terraform e Ansible na AWS

Este repositório implementa o fluxo do diagrama da atividade: o Terraform cria a infraestrutura na AWS; em seguida, o Ansible conecta ao Windows Server 2019 via WinRM HTTPS, instala o IIS e publica uma página de confirmação.

- Terraform cria VPC, sub-rede pública, gateway, rotas, grupo de segurança e instância EC2.
- HTTP (80) é liberado para visualizar a página. RDP (3389) e WinRM HTTPS (5986) são liberados somente para o IP administrativo configurado.
- O Ansible instala e inicia o IIS e verifica a página por HTTP.

> **Custos:** uma VM Windows pode gerar custos de EC2, disco e tráfego. Confira os preços AWS antes de começar e destrua os recursos ao terminar. Não abra RDP/WinRM para `0.0.0.0/0`. Nunca publique chave `.pem`, senha, `terraform.tfstate` ou `terraform.tfvars`.

## O que será necessário

1. Conta AWS com permissões para criar VPC, sub-rede, gateway, rotas, security group e instância EC2.
2. Terraform CLI 1.5+ e AWS CLI instalados no Windows.
3. Git instalado e acesso ao repositório [atividade4-iac-aws](https://github.com/marciobsb31/atividade4-iac-aws).
4. WSL 2 com Ubuntu para executar Ansible, Python e `pywinrm`. Ansible executa do Linux/WSL e gerencia o Windows remotamente.
5. Um IPv4 público estável/conhecido para restringir o acesso administrativo.

Use as páginas oficiais para instalar ferramentas: [Terraform no Windows](https://developer.hashicorp.com/terraform/install), [AWS CLI no Windows](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), [WSL](https://learn.microsoft.com/windows/wsl/install) e [Ansible no Ubuntu/WSL](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

## Passo 1 — Baixar o repositório

Abra o PowerShell e execute:

```powershell
cd "$HOME\Documents"
git clone https://github.com/marciobsb31/atividade4-iac-aws.git
cd atividade4-iac-aws
```

Se já clonou o projeto, entre na pasta existente em vez de cloná-lo novamente. Confirme que está na raiz e veja os arquivos:

```powershell
Get-Location
Get-ChildItem
```

Deve haver as pastas `terraform`, `ansible` e `evidence`.

## Passo 2 — Preparar a AWS

1. Entre no Console AWS e escolha uma região que ofereça EC2. Este exemplo começa com `us-east-1`.
2. Abra **EC2 → Key pairs (Pares de chaves) → Create key pair**. Escolha um nome simples, o tipo **RSA** e o formato `.pem`. Baixe o arquivo uma vez e guarde-o em local privado, por exemplo `C:\Users\SEU_USUARIO\.ssh\atividade4.pem`. Não o coloque na pasta do repositório.
3. Configure as credenciais da AWS CLI usando seu método autorizado. Para o fluxo simples com access key, abra PowerShell e execute:

   ```powershell
   aws configure
   ```

   Informe Access Key ID e Secret Access Key, defina região (`us-east-1`) e formato (`json`). Não coloque essas credenciais em arquivos do projeto. Em contas institucionais, siga o método de acesso fornecido pela instituição.

4. Confirme qual conta e região estão ativas:

   ```powershell
   aws sts get-caller-identity
   aws configure get region
   ```

   Se a região mostrada não for `us-east-1`, alinhe o valor em `terraform\terraform.tfvars` com a região da AWS e do key pair.
5. Descubra seu IPv4 público atual:

   ```powershell
   (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
   ```

   Anote o endereço e acrescente `/32`, por exemplo `198.51.100.25/32`. O exemplo de documentação `203.0.113.10/32` não é um IP real; substitua-o. Se seu IP mudar antes do provisionamento, atualize-o.

## Passo 3 — Configurar os valores do Terraform

Ainda na raiz do repositório, copie o exemplo:

```powershell
Copy-Item terraform\terraform.tfvars.example terraform\terraform.tfvars
notepad terraform\terraform.tfvars
```

No arquivo, substitua os valores:

```hcl
aws_region = "us-east-1"
key_name   = "NOME_EXATO_DO_KEY_PAIR"
admin_cidr = "SEU_IPV4_PUBLICO/32"
```

`key_name` é o nome do key pair na AWS (não o caminho do arquivo `.pem`). `admin_cidr` é seu IPv4 real com `/32`. Salve e feche o Notepad. O `terraform.tfvars` está excluído do Git intencionalmente: **não force sua inclusão**.

## Passo 4 — Validar e criar a infraestrutura com Terraform

No PowerShell, na raiz do repositório:

```powershell
New-Item -ItemType Directory -Force evidence | Out-Null
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=tfplan
```

Leia o plano. Ele deve criar recursos AWS do exemplo, inclusive uma instância Windows. Se houver erro, **não prossiga**: confira credenciais (`aws sts get-caller-identity`), região, nome do key pair e formato de `admin_cidr`. Só depois de revisar o plano, aplique uma única vez e grave o log:

```powershell
terraform -chdir=terraform apply tfplan 2>&1 | Tee-Object -FilePath evidence\terraform-apply.log
```

O Terraform pedirá confirmação; digite `yes`. Espere até terminar. O resultado deve indicar que o apply foi concluído e listar os outputs. Se o comando falhar, corrija a causa e repita o processo; o log de uma execução com falha não é evidência de sucesso.

Confira e anote os outputs:

```powershell
terraform -chdir=terraform output
$instanceId = terraform -chdir=terraform output -raw instance_id
$publicIp = terraform -chdir=terraform output -raw public_ip
$url = terraform -chdir=terraform output -raw http_url
```

Não publique o arquivo `terraform\terraform.tfstate`; ele contém dados internos do provisionamento.

## Passo 5 — Esperar a senha inicial do Windows

O Windows precisa terminar a inicialização antes de a senha ser disponibilizada. Aguarde alguns minutos. No PowerShell:

```powershell
$instanceId = terraform -chdir=terraform output -raw instance_id
aws ec2 get-password-data --instance-id $instanceId --priv-launch-key "C:\Users\SEU_USUARIO\.ssh\atividade4.pem" --query PasswordData --output text
```

Substitua o caminho pelo local real da chave `.pem`. Se o resultado vier vazio ou `None`, espere alguns minutos e repita. A senha recuperada é secreta: não a grave em arquivos, não a envie em mensagens e não a inclua em capturas ou logs. Mantenha o PowerShell aberto para consultar a senha novamente se necessário.

## Passo 6 — Preparar Ansible no WSL

Abra Ubuntu/WSL pelo menu Iniciar. Instale Ansible e as dependências no WSL (não no PowerShell):

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv
python3 -m venv ~/.venvs/atividade4
source ~/.venvs/atividade4/bin/activate
python -m pip install --upgrade pip
python -m pip install ansible "pywinrm>=0.4.3"
```

Entre na pasta do projeto compartilhada com o Windows. Para o caminho padrão usado neste guia:

```bash
cd "/mnt/c/Users/SEU_USUARIO/Documents/atividade4-iac-aws"
```

Substitua `SEU_USUARIO` pelo nome da pasta do seu perfil Windows. Se clonou em outro local, use o caminho WSL correspondente. Instale a coleção usada pelo playbook e confirme que os comandos existem:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible --version
```

## Passo 7 — Configurar inventário e executar Ansible

No PowerShell, pode abrir o inventário de exemplo:

```powershell
notepad ansible\inventory.ini.example
```

Faça uma cópia com o nome `inventory.ini` e substitua o endereço de exemplo pelo valor de `$publicIp` anotado:

```powershell
Copy-Item ansible\inventory.ini.example ansible\inventory.ini
notepad ansible\inventory.ini
```

O conteúdo final deve estar neste formato, com o IP real da instância:

```ini
[windows]
windows_iis ansible_host=IP_PUBLICO_REAL_DA_INSTANCIA
```

`ansible\inventory.ini` é local e está excluído do Git. Salve o arquivo. No Ubuntu/WSL, entre na pasta do projeto, ative o ambiente virtual se necessário e solicite a senha de forma oculta:

```bash
cd "/mnt/c/Users/SEU_USUARIO/Documents/atividade4-iac-aws"
source ~/.venvs/atividade4/bin/activate
read -s -p "Digite a senha Administrator recuperada pela AWS: " ANSIBLE_PASSWORD
export ANSIBLE_PASSWORD
echo
```

Digite/cole a senha quando solicitado; ela não aparecerá na tela. Em seguida, rode o playbook e grave o log:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml 2>&1 | tee evidence/ansible-playbook.log
```

Ao final, confira o `PLAY RECAP`: o host deve ter `failed=0` e `unreachable=0`. O playbook também testa se o IIS responde HTTP com status 200. Se o host estiver inacessível, confirme se o IP público ainda é o mesmo e se seu IPv4 atual corresponde ao `admin_cidr`; uma mudança de IP requer atualizar `terraform.tfvars` e aplicar novamente.

## Passo 8 — Conferir o IIS no navegador

No PowerShell, recupere o endereço:

```powershell
$url = terraform -chdir=terraform output -raw http_url
Write-Output $url
```

Abra esse endereço no navegador. A página deve mostrar **“IIS instalado e configurado com Ansible”**. Se não abrir imediatamente, aguarde um minuto e atualize. Também é possível testar com:

```powershell
Invoke-WebRequest -Uri $url
```

Não confunda uma página padrão da Microsoft/IIS com a página do playbook: a frase de confirmação deve estar visível.

## Passo 9 — Capturar as evidências solicitadas

Faça as capturas **após** Terraform e Ansible terminarem sem erro:

1. **Terraform:** `evidence\terraform-apply.log` deve ser o log completo da execução bem-sucedida e mostrar a criação dos recursos/outputs. Não edite um log para simular uma execução.
2. **Ansible:** `evidence\ansible-playbook.log` deve mostrar as tarefas concluídas, a checagem HTTP e `failed=0` no `PLAY RECAP`.
3. **Cloud:** no Console AWS, abra **EC2 → Instances**, selecione a instância criada e capture a tela mostrando o estado **Running**, tipo, região e nome/tags. O IP pode aparecer; não capture credenciais ou a chave privada.
4. **IIS:** capture o navegador com a URL da instância e a mensagem **“IIS instalado e configurado com Ansible”** visível.
5. Salve as duas imagens em `evidence`, por exemplo `evidence\aws-ec2-running.png` e `evidence\iis-page.png`. No Windows, use `Win+Shift+S`, salve cada imagem e copie os PNG para essa pasta.
6. Revise cada evidência: não pode conter senha, access key, secret key, arquivo `.pem`, terminal com segredo visível ou dados pessoais desnecessários.

## Passo 10 — Enviar as evidências ao GitHub e à disciplina

No PowerShell, volte à raiz do projeto e revise o que será publicado:

```powershell
git status --short
```

O resultado pode listar os dois logs e as imagens em `evidence`. **Não** pode listar `terraform.tfvars`, arquivos `.pem`, `terraform.tfstate`, diretório `.terraform` ou `ansible\inventory.ini`. Se algum segredo aparecer, não faça `git add`/`push`; remova-o e verifique novamente.

Adicione somente os arquivos de evidência e publique:

```powershell
git add evidence
git status --short
git commit -m "Add Terraform and Ansible execution evidence"
git push
```

Abra o repositório GitHub, confirme que os logs e imagens estão visíveis e copie o link:

`https://github.com/marciobsb31/atividade4-iac-aws`

Envie esse link no ambiente da disciplina juntamente com as capturas/logs se a plataforma pedir anexos separados. Escreva que o projeto provisiona Windows Server 2019 com Terraform e instala/verifica IIS usando Ansible. Não declare que a execução foi bem-sucedida até ter feito e conferido os passos acima.

## Passo 11 — Destruir os recursos para evitar cobranças

Depois de salvar e enviar as evidências, no PowerShell, na raiz do projeto:

```powershell
terraform -chdir=terraform destroy
```

Leia os recursos que serão removidos, digite `yes` e aguarde a conclusão. Destruir a VM pode fazer o endereço IP público deixar de funcionar; por isso, capture e guarde as evidências antes.
