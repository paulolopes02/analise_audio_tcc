# Análise Comparativa de Sinais de Áudio para TCC

Este repositório contém o script em MATLAB desenvolvido para o Trabalho de Conclusão de Curso **"Análise Comparativa da Qualidade Percebida em Diferentes Formatos de Áudio: Uma Abordagem Técnica e Sensorial"**.

- **Autores:** Dante Henrique Neves Santos, Paulo Vitor Lopes
- **Orientador:** Prof. Dr. Antonio Carlos Pinho
- **Instituição:** Universidade Tecnológica Federal do Paraná (UTFPR)

## Descrição do Projeto

O script `analise_audio_TCC.m` foi projetado para realizar uma análise técnica e quantitativa de dois arquivos de áudio, com o objetivo de comparar suas características espectrais e de potência. O principal caso de uso é a comparação de uma mesma faixa musical obtida de diferentes serviços de streaming (como Tidal e Spotify) para identificar as diferenças introduzidas pelos respectivos processos de codificação e compressão.

O script automatiza todo o processo, desde a seleção dos arquivos até a geração de um conjunto de gráficos comparativos.

## Funcionalidades Principais

O script executa as seguintes etapas de forma automática:

1.  **Seleção Interativa de Arquivos:** Abre janelas para que o usuário selecione os dois arquivos de áudio a serem comparados (denominados Sinal Y para Tidal e Sinal X para Spotify).
2.  **Correção de Atraso (Alinhamento Temporal):** Calcula automaticamente a defasagem temporal entre os dois sinais usando `finddelay` e alinha os áudios para garantir uma comparação precisa.
3.  **Normalização de Amplitude:** Ajusta o ganho de um dos sinais para que ambos tenham a mesma amplitude média, eliminando diferenças de volume que poderiam enviesar a análise de potência.
4.  **Análise FFT em Segmentos:** Divide os sinais em segmentos e calcula a Transformada Rápida de Fourier (FFT) para cada um.
5.  **Seleção Automática de Segmento:** De forma inteligente, o script identifica e seleciona para análise o segmento onde a **diferença espectral** entre os dois sinais é máxima. Isso foca a análise na parte mais relevante do áudio.
6.  **Análise de Potência por Bandas:** Calcula a potência média dos sinais em bandas de frequência de 100 Hz, até um máximo de 30 kHz.
7.  **Geração de Gráficos:** Ao final, gera 6 figuras distintas para visualização e interpretação dos resultados:
    - **Gráfico 1:** Espectro de Frequência (dB) do segmento mais divergente.
    - **Gráfico 2:** Forma de onda no tempo do segmento analisado.
    - **Gráfico 3:** Potência Média por Banda de Frequência.
    - **Gráfico 4:** Relação de Potência Y/X (Tidal/Spotify) em dB.
    - **Gráfico 5:** Relação de Potência X/Y (Spotify/Tidal) em dB.
    - **Gráfico 6:** Forma de onda completa dos sinais alinhados e normalizados.

## Requisitos

- **MATLAB:** Versão R2020a ou mais recente.
- **Toolboxes:**
  - **Signal Processing Toolbox™:** Necessário para a função `finddelay`.

## Como Usar

1.  Clone ou baixe este repositório.
2.  Coloque as gravções a serem utilizadas na pasta do projeto
3.  Abra o MATLAB.
4.  Navegue até a pasta onde o script `analise_audio_TCC.m` está localizado.
5.  Execute o script no Command Window do MATLAB:
    ```matlab
    analise_audio_TCC
    ```
6.  Uma janela de seleção de arquivo será aberta. **Primeiro, selecione o arquivo de áudio correspondente ao Tidal (Sinal Y)**.
7.  Uma segunda janela será aberta. **Selecione o arquivo de áudio correspondente ao Spotify (Sinal X)**.
8.  O script executará toda a análise automaticamente. O progresso será exibido no Command Window e, ao final, as 6 janelas de gráficos serão abertas.
