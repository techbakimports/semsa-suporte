import re
with open('suporte.ps1', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace all smart quotes
text = text.replace('\u201c', '"')
text = text.replace('\u201d', '"')
text = text.replace('\u2018', "'")
text = text.replace('\u2019', "'")

# Fix the spaces for [INFO] [ERRO] [SUCESSO] [ALERTA] [DICA] just in case
text = text.replace('"[INFO]', '" [INFO]')
text = text.replace('"[ERRO]', '" [ERRO]')
text = text.replace('"[SUCESSO]', '" [SUCESSO]')
text = text.replace('"[ALERTA]', '" [ALERTA]')
text = text.replace('"[DICA]', '" [DICA]')

with open('suporte.ps1', 'w', encoding='utf-8') as f:
    f.write(text)
print('Fixed all smart quotes and info brackets!')
