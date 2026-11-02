# Análise funcional MM com ARC-1 — guia rápido (somente leitura)

> **Para quem:** consultor(a) funcional (ex.: MM) que quer usar o ARC-1 dentro do Claude Code só para
> **analisar** o SAP — ler dados, entender customizing e comportamento do sistema — **sem alterar nada**.
> É um atalho prático por cima do [`SETUP_FOR_CLAUDE.md`](../SETUP_FOR_CLAUDE.md); para o setup completo
> ou trabalho de desenvolvimento, use aquele.
>
> *(Quick read-only / functional-analysis path. Written in PT-BR for a functional consultant audience.)*

---

## 0. O que você vai conseguir
Pedir ao Claude, em português, coisas como *"lê o pedido de compra 4500001234"* ou *"mostra os campos de
MRP do material X no centro 1000"* — e ele responde lendo direto do SAP, **sem SAP GUI e sem mudar nada**.

---

## 1. Pré-requisitos
```bash
node -v        # precisa de Node 18+ (20+ recomendado) — instale de https://nodejs.org se faltar
claude --version
```

---

## 2. Instalar o ARC-1 (plugin — traz MCP + skills)
É o caminho mais simples: um comando instala o servidor MCP **e** todas as skills ABAP (incluindo
`abap-rap-adt`). Não precisa copiar skill na mão.

```bash
claude plugin marketplace add arc-mcp/arc-1
claude plugin install arc-1@arc-1
```

> Se der erro `Unrecognized keys: "$schema", ...` numa versão antiga do Claude Code: rode
> `claude update`, reinicie o Claude e reinstale.

---

## 3. Conectar o sistema (modo leitura)
Para análise de **dados** (ler conteúdo de tabela, rodar SQL de consulta) o jeito mais limpo é o
**helper multi-sistema**, porque as *flags de leitura* ficam guardadas no `.env` do sistema.

**Windows (PowerShell):**
```powershell
# Instala o helper + template (uma vez)
New-Item -ItemType Directory -Force "$HOME\.arc1\systems","$HOME\.arc1\secrets" | Out-Null
Copy-Item .\templates\arc1env.ps1   "$HOME\.arc1\arc1env.ps1"
Copy-Item .\templates\_template.env "$HOME\.arc1\systems\_template.env"
Add-Content $PROFILE "`n. `"$HOME\.arc1\arc1env.ps1`""
. "$HOME\.arc1\arc1env.ps1"

# Cria o arquivo do seu sistema
Copy-Item "$HOME\.arc1\systems\_template.env" "$HOME\.arc1\systems\<apelido>.env"
notepad "$HOME\.arc1\systems\<apelido>.env"
```

Preencha o `<apelido>.env` assim (exemplo on-prem) — **sem a senha**:
```
SAP_URL=http://SEU-HOST:PORTA-ADT/     # ex.: http://saphost.empresa.com:8000/  (RISE = https://host na 443, sem :44300)
SAP_CLIENT=100
SAP_USER=SEU_USUARIO
SAP_INSECURE=true                       # cert on-prem / CA interna

# >>> ESSENCIAL para ANÁLISE — libera leitura de dados <<<
SAP_ALLOW_DATA_PREVIEW=true             # ler conteúdo de tabela (EKKO, MARC, MSEG...)
SAP_ALLOW_FREE_SQL=true                 # rodar SQL/CDS de consulta
```

> 🔒 **Somente leitura:** **nunca** coloque `SAP_ALLOW_WRITES` (nem `SAP_ALLOWED_PACKAGES` /
> `SAP_ALLOWED_TRANSPORTS`). Sem essas flags, as ferramentas de escrita nem aparecem — o ARC-1 fica
> limitado a ler. É o modo mais seguro para análise funcional.

Guarde a senha criptografada (DPAPI — só você, nesta máquina, descriptografa):
```powershell
Set-Arc1Secret <apelido>
```

> Também dá para usar o `claude plugin configure arc-1@arc-1` (guarda a senha no keychain do SO). Nesse
> caminho, garanta que `SAP_ALLOW_DATA_PREVIEW` e `SAP_ALLOW_FREE_SQL` estejam visíveis para o servidor
> ARC-1 (via o `.env` do helper acima) — senão ele conecta mas não lê conteúdo de tabela.

---

## 4. Testar a conexão (smoke test read-only)
Ative o sistema e rode um teste de leitura — **na mesma linha** (as variáveis não persistem entre chamadas):
```powershell
. $HOME\.arc1\arc1env.ps1; Use-Arc1 <apelido>; arc1 call SAPRead --arg type=SYSTEM --output json
```
Retornou as infos do sistema? Conectado. 🎉

### Dados para pedir ao Basis
- **Host** do servidor de aplicação
- **Porta ADT/ICM** — geralmente `80<NN>` (HTTP) ou `443<NN>` (HTTPS), `NN` = nº da instância
- **Client** e **usuário**
- Confirmar que o **ADT está ativo** (nós `sap/bc/adt` ligados no SICF) — em S/4 moderno já costuma vir

---

## 5. Usar no Claude — exemplos MM
Abra o Claude Code **no mesmo shell** (pra herdar a conexão) e peça em linguagem natural:

- "Lê o cabeçalho e itens do pedido de compra 4500001234 (EKKO/EKPO) e me resume."
- "Mostra os campos de MRP do material MAT-001 no centro 1000 (MARC)."
- "Quais movimentos de estoque (MSEG/MKPF) esse material teve no mês passado?"
- "Cruza EKPO com EKBE pra ver o histórico de recebimento desse pedido."
- "Explica o que a transação/report X faz e onde essa regra está implementada."
- "Por que esse pedido não gerou necessidade no MRP? Investiga os dados."
- "Lista o customizing de tipos de movimento (T156) relacionados a 101/102."

> Tabelas MM úteis: `EKKO`/`EKPO`/`EKET`/`EKBE` (compras), `EBAN` (requisições),
> `MARA`/`MARC`/`MARD`/`MBEW` (material), `MKPF`/`MSEG` (movimentos), `MDKP`/`MDTB` (MRP),
> `T156`/`T024`/`T683*` (customizing).

---

## 6. Problemas comuns (modo leitura)
| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `404` / `403` ao conectar | ADT não ativo no SICF | Basis liga os nós `sap/bc/adt` |
| Erro de certificado / trava | CA interna não confiável no Node | manter `SAP_INSECURE=true` |
| Conecta mas "não lê dados" | faltou flag de leitura | `SAP_ALLOW_DATA_PREVIEW=true` e `SAP_ALLOW_FREE_SQL=true` no `.env` |
| Variáveis "somem" | cada shell novo começa limpo | re-ative na mesma linha (`. ...arc1env.ps1; Use-Arc1 <apelido>; arc1 ...`) |
| `ENETUNREACH` ao instalar | VPN corporativa | tente com a VPN desligada |

---

*Guia pessoal e não oficial. ARC-1 é um produto de terceiros; siga as políticas de segurança e de
change-management da sua empresa em qualquer sistema SAP real.*
