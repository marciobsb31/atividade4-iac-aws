# Atividade 4 — Terraform e Ansible na AWS

Exemplo de Infraestrutura como Código baseado no diagrama da atividade:

- Terraform provisiona uma VPC pública, uma instância Windows Server 2019 e as regras de rede.
- Ansible configura o acesso WinRM por HTTPS e instala o IIS com uma página de demonstração.
- O acesso HTTP ao IIS fica disponível publicamente. RDP (3389) e WinRM HTTPS (5986) ficam limitados ao CIDR administrativo informado.

> **Custos e segurança:** uma instância EC2 Windows pode gerar custos enquanto estiver ligada, e a cobrança pode incluir armazenamento e tráfego. Confira os preços da região antes de executar. Não abra RDP/WinRM para `0.0.0.0/0`, não publique chaves privadas, senhas ou o estado do Terraform. Execute `terraform destroy` ao terminar se não precisar manter o ambiente.

## Pré-requisitos

- Conta AWS com permissões para criar VPC, sub-rede, gateway, tabela de rotas, grupo de segurança e instância EC2.
- AWS CLI configurada (`aws configure` ou outro método seguro de credenciais).
- Terraform 1.5 ou superior.
- Um key pair EC2 RSA já criado na região escolhida e seu arquivo privado `.pem`, guardado fora deste repositório.
- Ansible instalado em um controlador Linux ou WSL, com Python e `pywinrm`.

## 1. Configurar e provisionar com Terraform

No PowerShell, na pasta do repositório:

```powershell
Copy-Item terraform\terraform.tfvars.example terraform\terraform.tfvars
```

Edite `terraform\terraform.tfvars`: informe o nome do key pair existente e seu IPv4 público com máscara `/32` em `admin_cidr` (por exemplo, `203.0.113.10/32`; substitua pelo seu IP real). A região do key pair deve ser a mesma de `aws_region`.

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=tfplan
terraform -chdir=terraform apply tfplan 2>&1 | Tee-Object -FilePath evidence\terraform-apply.log
```

O último comando aplica o plano uma vez e grava o log em `evidence\terraform-apply.log`.

Guarde os valores exibidos por `terraform -chdir=terraform output`, em especial `instance_id` e `public_ip`. O endpoint HTTP pode ser conferido com `terraform -chdir=terraform output -raw http_url`.

## 2. Obter a senha inicial do Windows

Após a instância iniciar, o Windows pode levar alguns minutos para disponibilizar a senha. No PowerShell, substitua o caminho pelo arquivo privado do key pair:

```powershell
$instanceId = terraform -chdir=terraform output -raw instance_id
$password = aws ec2 get-password-data --instance-id $instanceId --priv-launch-key "C:\caminho\seguro\minha-chave.pem" --query PasswordData --output text
$env:ANSIBLE_PASSWORD = $password
```

O AWS CLI pode retornar uma senha vazia enquanto ela ainda está sendo gerada. Aguarde e repita o comando `get-password-data` nesse caso. Não salve a senha no inventário nem em arquivos versionados.

## 3. Instalar IIS com Ansible

Em um controlador Linux/WSL com Ansible instalado, instale os requisitos:

```bash
python3 -m pip install "pywinrm>=0.4.3"
ansible-galaxy collection install -r ansible/requirements.yml
```

Crie o inventário local a partir do exemplo e substitua o IP:

```bash
cp ansible/inventory.ini.example ansible/inventory.ini
```

No PowerShell, pode-se abrir o arquivo para edição com `notepad ansible\inventory.ini`. Para o controlador WSL, exporte a senha obtida anteriormente, por exemplo `export ANSIBLE_PASSWORD='senha-obtida'`, e execute:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml 2>&1 | tee evidence/ansible-playbook.log
```

O playbook aguarda a conexão WinRM e instala o IIS, inicia o serviço e publica uma página de teste. A validação final consulta o endereço HTTP público.

## 4. Evidências para a entrega

Depois de executar os comandos em sua própria conta:

1. Salve o log real do `terraform apply` em `evidence/terraform-apply.log` e do Ansible em `evidence/ansible-playbook.log`.
2. Capture uma imagem do console AWS mostrando a instância EC2 em execução e outra da página IIS aberta pelo `http_url` (ou uma imagem que mostre claramente os dois resultados).
3. Revise logs e imagens antes de publicá-los. Remova senhas, tokens, dados pessoais e informações que não queira divulgar; não inclua arquivos `.pem`, `terraform.tfstate` nem `terraform.tfvars`.
4. Envie o link do repositório GitHub e as evidências solicitadas no ambiente da disciplina.

Este workspace ainda não está conectado a uma conta AWS. Os logs, a instância e as capturas devem ser gerados por você após configurar suas credenciais.

## Limpeza

Quando terminar e tiver guardado as evidências:

```powershell
terraform -chdir=terraform destroy
```

Confirme a destruição no prompt do Terraform. Ela remove os recursos criados por este exemplo.
