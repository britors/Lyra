# Referência histórica do Calamares

Este diretório preserva a antiga configuração da imagem apenas como
referência para auditoria de comportamento e migração do instalador Rust.
Ele fica fora de `kiwi/root/`, não é copiado para a ISO e não instala nem
executa o Calamares.

A Beta 2 usa exclusivamente o pacote `lyra-installer`; os testes de release
devem validar esse caminho em vez de comparar ou oferecer fallback para o
instalador antigo.
