clc;            
clear;          
close all;      
format long;    

% --- Par�metros Iniciais ---
% m_segmento_analise ser� determinado automaticamente
Na_fft = 17;                
Namost_fft = 2^Na_fft;      

% --- SELE��O INTERATIVA DOS ARQUIVOS DE �UDIO ---
fprintf('Selecionando arquivos de �udio...\n');
audio_filter_spec = {'*.wav;*.mp3;*.flac;*.m4a;*.ogg','Arquivos de �udio (*.wav, *.mp3, *.flac, *.m4a, *.ogg)'; ...
                     '*.wav','Arquivos WAV (*.wav)'; ...
                     '*.mp3','Arquivos MP3 (*.mp3)'; ...
                     '*.flac','Arquivos FLAC (*.flac)'; ...
                     '*.m4a','Arquivos M4A (*.m4a)'; ...
                     '*.ogg','Arquivos OGG (*.ogg)'; ...
                     '*.*','Todos os Arquivos (*.*)'};

[arquivo_y_nome, arquivo_y_caminho] = uigetfile(audio_filter_spec, 'Selecione o arquivo de �udio do TIDAL (Sinal Y)');
if isequal(arquivo_y_nome,0) || isequal(arquivo_y_caminho,0) 
    disp('Sele��o do arquivo Y (Tidal) cancelada. Encerrando.');
    return; 
else
    caminho_completo_y = fullfile(arquivo_y_caminho, arquivo_y_nome); 
    fprintf('Arquivo Y (Tidal) selecionado: %s\n', caminho_completo_y);
end

[arquivo_x_nome, arquivo_x_caminho] = uigetfile(audio_filter_spec, 'Selecione o arquivo de �udio do SPOTIFY (Sinal X)');
if isequal(arquivo_x_nome,0) || isequal(arquivo_x_caminho,0) 
    disp('Sele��o do arquivo X (Spotify) cancelada. Encerrando.');
    return;
else
    caminho_completo_x = fullfile(arquivo_x_caminho, arquivo_x_nome); 
    fprintf('Arquivo X (Spotify) selecionado: %s\n', caminho_completo_x);
end

% --- Leitura dos Arquivos de �udio Selecionados ---
fprintf('Lendo arquivos de �udio selecionados...\n');
try
    [y_audio_completo, Fs] = audioread(caminho_completo_y);     
    [x_audio_completo, Fs_x] = audioread(caminho_completo_x); 
catch ME
    error('Erro ao ler arquivos de �udio: %s\nVerifique se s�o v�lidos.', ME.message);
end

if Fs ~= Fs_x, error('As taxas de amostragem diferentes!'); end 

% --- C�lculo e Aplica��o Autom�tica do Atraso (D1) ---
fprintf('Calculando defasagem inicial (D1)...\n');
N_amostras_para_finddelay = min(round(5*Fs), min(size(y_audio_completo,1), size(x_audio_completo,1)));
max_abs_delay_samples = round(1*Fs); 

if N_amostras_para_finddelay > 0
    y_trecho_finddelay = y_audio_completo(1:N_amostras_para_finddelay, 1);
    x_trecho_finddelay = x_audio_completo(1:N_amostras_para_finddelay, 1);
    D1 = finddelay(y_trecho_finddelay, x_trecho_finddelay, max_abs_delay_samples); 
else
    warning('�udios curtos para finddelay. D1=0.'); D1 = 0;
end
fprintf('D1 (atraso de X em Y): %d amostras (%.4f s)\n', D1, D1/Fs);

idx_start_y = 1; idx_start_x = 1;
if D1 > 0 
    idx_start_x = D1 + 1;
    fprintf('Ajuste: Sinal X (Spotify) come�ar� da amostra %d.\n', idx_start_x);
elseif D1 < 0 
    idx_start_y = abs(D1) + 1;
    fprintf('Ajuste: Sinal Y (Tidal) come�ar� da amostra %d.\n', idx_start_y);
else
    fprintf('Nenhum ajuste de atraso inicial por D1.\n');
end

N_disponivel_y = size(y_audio_completo,1) - idx_start_y + 1;
N_disponivel_x = size(x_audio_completo,1) - idx_start_x + 1;
N_efetiva_processar = min(N_disponivel_y, N_disponivel_x); 

if N_efetiva_processar <= 0, error('Amostras insuficientes ap�s ajuste de atraso.'); end
if N_efetiva_processar < Namost_fft, warning('N� amostras (%d) < FFT (%d).', N_efetiva_processar, Namost_fft); end
fprintf('N� efetivo de amostras/canal: %d (%.2f s)\n', N_efetiva_processar, N_efetiva_processar/Fs);

y1D = y_audio_completo(idx_start_y : idx_start_y + N_efetiva_processar - 1, 1);
x1D = x_audio_completo(idx_start_x : idx_start_x + N_efetiva_processar - 1, 1);

% --- Normaliza��o de Amplitude ---
fprintf('Normalizando amplitudes...\n');
y1D_media_abs = mean(abs(y1D)); x1D_media_abs = mean(abs(x1D));
if x1D_media_abs == 0, ka_ganho = 1; warning('M�dia X � zero, ka=1.'); else ka_ganho = y1D_media_abs / x1D_media_abs; end
x1D = ka_ganho * x1D; 

% --- C�lculo da FFT por Segmentos ---
num_segmentos_fft = floor(N_efetiva_processar / Namost_fft); 
if num_segmentos_fft == 0
    warning('Nenhum segmento FFT completo. An�lises FFT limitadas.');
    pi_segmento = []; pf_segmento = []; x_fft = []; y_fft = []; f_eixo_fft = [];
else
    fprintf('Calculando FFT em %d segmentos...\n', num_segmentos_fft);
    pi_segmento = zeros(num_segmentos_fft, 1); pf_segmento = zeros(num_segmentos_fft, 1);
    x_fft = zeros(num_segmentos_fft, Namost_fft); y_fft = zeros(num_segmentos_fft, Namost_fft);
    a_idx_fft = 1; 
    for i_seg = 1:num_segmentos_fft
        b_idx_fft = a_idx_fft + Namost_fft - 1; 
        pi_segmento(i_seg) = a_idx_fft; pf_segmento(i_seg) = b_idx_fft;
        x_fft(i_seg, :) = abs(fft(x1D(a_idx_fft:b_idx_fft), Namost_fft));
        y_fft(i_seg, :) = abs(fft(y1D(a_idx_fft:b_idx_fft), Namost_fft));
        a_idx_fft = b_idx_fft; 
    end
    f_eixo_fft = Fs*(0:(Namost_fft/2-1))/Namost_fft;
end
small_value_log = 1e-12; 

% --- DETERMINA��O AUTOM�TICA DO SEGMENTO DE AN�LISE (Crit�rio: Diferen�a Espectral) ---
m_segmento_analise = 1; % Valor padr�o caso n�o haja segmentos ou ocorra erro
if num_segmentos_fft > 0
    fprintf('Determinando segmento com maior diferen�a espectral normalizada...\n');
    spectral_differences = zeros(num_segmentos_fft, 1);

    for i_seg_spec = 1:num_segmentos_fft
        % Pega a primeira metade do espectro (magnitudes)
        y_fft_half = y_fft(i_seg_spec, 1:floor(Namost_fft/2));
        x_fft_half = x_fft(i_seg_spec, 1:floor(Namost_fft/2));
        
        % Normaliza��o L2 para focar na forma espectral
        norm_y = norm(y_fft_half);
        norm_x = norm(x_fft_half);
        
        if norm_y > small_value_log % Evita divis�o por zero ou por valor muito pequeno
            y_fft_norm = y_fft_half / norm_y;
        else
            y_fft_norm = zeros(size(y_fft_half)); % Espectro nulo se norma for zero
        end
        
        if norm_x > small_value_log % Evita divis�o por zero ou por valor muito pequeno
            x_fft_norm = x_fft_half / norm_x;
        else
            x_fft_norm = zeros(size(x_fft_half)); % Espectro nulo se norma for zero
        end
        
        % Dist�ncia Euclidiana entre os espectros L2-normalizados
        spectral_differences(i_seg_spec) = norm(y_fft_norm - x_fft_norm);
    end
    
    if isempty(spectral_differences) || all(isnan(spectral_differences)) || all(spectral_differences < small_value_log)
        warning('N�o foi poss�vel determinar diferen�as espectrais significativas. Usando segmento 1.');
        m_segmento_analise_auto = 1;
        if num_segmentos_fft == 0, m_segmento_analise_auto = 0; end % Caso extremo
    else
        [max_spectral_diff_val, m_segmento_analise_auto] = max(spectral_differences);
        fprintf('Segmento %d selecionado automaticamente (maior diferen�a espectral normalizada: %.4f)\n', m_segmento_analise_auto, max_spectral_diff_val);
    end
    
    m_segmento_analise = m_segmento_analise_auto; % Usa o segmento com maior diferen�a espectral
else
    fprintf('Nenhum segmento FFT para analisar a diferen�a espectral.\n');
    m_segmento_analise = 0; % Indica que n�o h� segmento v�lido
end


% --- Detec��o de Picos no Espectro ---
% (O restante do c�digo continua como antes, utilizando o m_segmento_analise determinado dinamicamente)
y_fft_m = []; x_fft_m = []; 
if num_segmentos_fft > 0 && m_segmento_analise > 0 
    fprintf('Detectando picos espectrais - Seg. %d...\n', m_segmento_analise);
    
    x_fft_m = x_fft(m_segmento_analise, :);
    vmax_pico_x_geral = 0; if ~isempty(x_fft_m) && length(x_fft_m) >= Namost_fft/2, vmax_pico_x_geral = max(x_fft_m(1:Namost_fft/2)); end
    threshold_pico_x = 0.0001 * vmax_pico_x_geral; valores_pico_x = []; freq_pico_x = [];
    if ~isempty(f_eixo_fft) && ~isempty(x_fft_m) && length(x_fft_m) >= Namost_fft/2
        for j_pico = 2:(Namost_fft/2 - 1)
            if (x_fft_m(j_pico) > threshold_pico_x) && (x_fft_m(j_pico) >= x_fft_m(j_pico-1)) && (x_fft_m(j_pico) > x_fft_m(j_pico+1))
                valores_pico_x(end+1) = x_fft_m(j_pico); freq_pico_x(end+1) = f_eixo_fft(j_pico); 
            end; end; end
    y_fft_m = y_fft(m_segmento_analise, :);
    vmax_pico_y_geral = 0; if ~isempty(y_fft_m) && length(y_fft_m) >= Namost_fft/2, vmax_pico_y_geral = max(y_fft_m(1:Namost_fft/2)); end
    threshold_pico_y = 0.0001 * vmax_pico_y_geral; valores_pico_y = []; freq_pico_y = [];
    if ~isempty(f_eixo_fft) && ~isempty(y_fft_m) && length(y_fft_m) >= Namost_fft/2
        for j_pico = 2:(Namost_fft/2 - 1)
            if (y_fft_m(j_pico) > threshold_pico_y) && (y_fft_m(j_pico) >= y_fft_m(j_pico-1)) && (y_fft_m(j_pico) > y_fft_m(j_pico+1))
                valores_pico_y(end+1) = y_fft_m(j_pico); freq_pico_y(end+1) = f_eixo_fft(j_pico);
            end; end; end
else
    if m_segmento_analise > 0 
        fprintf('Sem segmentos FFT, pulando picos e pot�ncia.\n');
    end
end

% --- C�lculo da Pot�ncia por Bandas ---
num_bandas_finais_plot = 0; potencia_y_banda = []; potencia_x_banda = [];
relacao_yx_pot_db = []; relacao_xy_pot_db = [];
if num_segmentos_fft > 0 && m_segmento_analise > 0 && ~isempty(y_fft_m) && ~isempty(x_fft_m)
    fprintf('Calculando pot�ncia por bandas - Seg. %d...\n', m_segmento_analise);
    max_freq_analise_banda = 30000; largura_banda_hz = 100; 
    num_max_bandas_pot = ceil(max_freq_analise_banda / largura_banda_hz);
    potencia_y_banda = zeros(num_max_bandas_pot, 1); potencia_x_banda = zeros(num_max_bandas_pot, 1); 
    num_bandas_calculadas_y = 0; num_bandas_calculadas_x = 0;
    for side = 1:2 
        if side == 1, current_fft_segment = y_fft_m; else current_fft_segment = x_fft_m; end
        energia_acum_banda = zeros(num_max_bandas_pot,1); contagem_banda = zeros(num_max_bandas_pot,1); idx_banda_atual = 1;
        if ~isempty(f_eixo_fft) && ~isempty(current_fft_segment) && length(current_fft_segment) >= Namost_fft/2
            for i_freq = 1:length(f_eixo_fft) 
                freq_atual = f_eixo_fft(i_freq);
                if freq_atual > max_freq_analise_banda || idx_banda_atual > num_max_bandas_pot, break; end
                if freq_atual <= (idx_banda_atual * largura_banda_hz)
                    if i_freq <= length(current_fft_segment)
                        energia_acum_banda(idx_banda_atual) = energia_acum_banda(idx_banda_atual) + current_fft_segment(i_freq)^2;
                        contagem_banda(idx_banda_atual) = contagem_banda(idx_banda_atual) + 1;
                    end
                else
                    idx_banda_atual = idx_banda_atual + 1;
                    if idx_banda_atual <= num_max_bandas_pot && freq_atual <= (idx_banda_atual * largura_banda_hz)
                        if i_freq <= length(current_fft_segment)
                            energia_acum_banda(idx_banda_atual) = energia_acum_banda(idx_banda_atual) + current_fft_segment(i_freq)^2;
                            contagem_banda(idx_banda_atual) = contagem_banda(idx_banda_atual) + 1;
                        end
                    elseif idx_banda_atual > num_max_bandas_pot, break; end
                end; end; end
        if side == 1, potencia_y_banda(1:idx_banda_atual) = energia_acum_banda(1:idx_banda_atual) ./ max(1, contagem_banda(1:idx_banda_atual)); num_bandas_calculadas_y = idx_banda_atual;
        else potencia_x_banda(1:idx_banda_atual) = energia_acum_banda(1:idx_banda_atual) ./ max(1, contagem_banda(1:idx_banda_atual)); num_bandas_calculadas_x = idx_banda_atual; end
    end
    num_bandas_finais_plot = min([num_bandas_calculadas_y, num_bandas_calculadas_x, 300]);
    if num_bandas_finais_plot > 0
        pot_y_plot = potencia_y_banda(1:num_bandas_finais_plot); pot_x_plot = potencia_x_banda(1:num_bandas_finais_plot);
        relacao_yx_pot = pot_y_plot ./ max(small_value_log, pot_x_plot); 
        relacao_xy_pot = pot_x_plot ./ max(small_value_log, pot_y_plot); 
        relacao_yx_pot_db = 20*log10(max(relacao_yx_pot, small_value_log));
        relacao_xy_pot_db = 20*log10(max(relacao_xy_pot, small_value_log));
    else warning('Nenhuma banda para plotar rela��es de pot�ncia.'); end
end

% --- Plotagem dos Gr�ficos ---
% (Plots 1 a 6, como no script anterior, com verifica��es adicionais para dados vazios)
fprintf('Gerando gr�ficos...\n');
% GR�FICO 1: Espectro de Frequ�ncia
figure;
if num_segmentos_fft > 0 && m_segmento_analise > 0 && ~isempty(f_eixo_fft) && ~isempty(y_fft_m) && ~isempty(x_fft_m) && ...
   length(y_fft_m) >= length(f_eixo_fft) && length(x_fft_m) >= length(f_eixo_fft)
    semilogx(f_eixo_fft, 20*log10(max(y_fft_m(1:length(f_eixo_fft)),small_value_log)), 'b', ...
             f_eixo_fft, 20*log10(max(x_fft_m(1:length(f_eixo_fft)),small_value_log)), 'r');
    title('Espectro (dB)');
    xlabel('Frequ�ncia (Hz)'); ylabel('Magnitude (dB)');
    legend('Sinal Y (Tidal)', 'Sinal X (Spotify)'); grid on;
    if ~isempty(f_eixo_fft) && length(f_eixo_fft) > 1 && f_eixo_fft(1) < max(f_eixo_fft(end),max_freq_analise_banda)
        xlim([max(20,f_eixo_fft(1)) max(f_eixo_fft(end),max_freq_analise_banda)]);
    elseif ~isempty(f_eixo_fft) && length(f_eixo_fft) == 1 
         xlim([max(20, f_eixo_fft(1)*0.5) max(f_eixo_fft(1)*1.5, max_freq_analise_banda)]); 
    end
else disp('Dados insuficientes para Gr�fico 1 (Espectro).'); end

% GR�FICO 2: Sinais no Tempo, segmento m
figure;
if num_segmentos_fft > 0 && m_segmento_analise > 0 && m_segmento_analise <= num_segmentos_fft && ...
   ~isempty(pi_segmento) && size(pi_segmento,1) >= m_segmento_analise && pf_segmento(m_segmento_analise) <= N_efetiva_processar && ...
   pi_segmento(m_segmento_analise) > 0 
    indices_plot_tempo_segmento = pi_segmento(m_segmento_analise):pf_segmento(m_segmento_analise);
    if max(indices_plot_tempo_segmento) <= N_efetiva_processar 
        tempo_eixo_segmento = (indices_plot_tempo_segmento-1)/Fs;
        plot(tempo_eixo_segmento, y1D(indices_plot_tempo_segmento), 'b', ...
             tempo_eixo_segmento, x1D(indices_plot_tempo_segmento), 'r');
        title('Sinais no Tempo ');
        xlabel('Tempo no Segmento (s)'); ylabel('Amplitude Normalizada');
        legend('Sinal Y (Tidal)', 'Sinal X (Spotify)'); grid on;
    else disp('�ndices do segmento para Gr�fico 2 fora dos limites.'); end
else disp('Dados insuficientes ou inv�lidos para Gr�fico 2.'); end

% GR�FICO 3: Pot�ncia por Banda (COM SEMILOGY)
figure;
if num_bandas_finais_plot > 0 && ~isempty(potencia_y_banda) && ~isempty(potencia_x_banda)
    eixo_bandas_plot = (1:num_bandas_finais_plot) * largura_banda_hz - (largura_banda_hz/2);
    semilogy(eixo_bandas_plot, potencia_y_banda(1:num_bandas_finais_plot), 'b.-', ...
             eixo_bandas_plot, potencia_x_banda(1:num_bandas_finais_plot), 'r.-');
    title('Pot�ncia M�dia por Banda de Frequ�ncia');
    xlabel('Frequ�ncia (Hz)');
    ylabel('Pot�ncia M�dia (unidade^2)');
    legend('Sinal Y (Tidal)', 'Sinal X (Spotify)'); grid on;
    xlim([0 max_freq_analise_banda]);
    current_ylim_g3 = ylim; 
    min_val_g3_vec = [potencia_y_banda(potencia_y_banda>0 & isfinite(potencia_y_banda)); ...
                      potencia_x_banda(potencia_x_banda>0 & isfinite(potencia_x_banda))];
    if ~isempty(min_val_g3_vec)
        min_val_g3 = min(min_val_g3_vec);
        if current_ylim_g3(1) <= 0 && min_val_g3 > 0, ylim([min_val_g3*0.1 current_ylim_g3(2)]);
        elseif current_ylim_g3(1) <= 0, ylim([small_value_log current_ylim_g3(2)]); end
    elseif current_ylim_g3(1) <=0, ylim([small_value_log current_ylim_g3(2)]); end
else disp('Dados insuficientes para Gr�fico 3.'); end

% GR�FICOS 4 e 5 (Rela��es de Pot�ncia)
figure;
if ~isempty(relacao_yx_pot_db) && num_bandas_finais_plot > 0
    eixo_bandas_plot = (1:num_bandas_finais_plot) * largura_banda_hz - (largura_banda_hz/2);
    plot(eixo_bandas_plot, relacao_yx_pot_db(1:num_bandas_finais_plot), 'g.-');
    title('Rela��o Pot. Y/X por Banda');
    xlabel('Frequ�ncia (Hz)');
    ylabel('Rela��o Y/X (dB)'); grid on; xlim([0 max_freq_analise_banda]);
else disp('Dados insuficientes para Gr�fico 4.'); end
figure;
if ~isempty(relacao_xy_pot_db) && num_bandas_finais_plot > 0
    eixo_bandas_plot = (1:num_bandas_finais_plot) * largura_banda_hz - (largura_banda_hz/2);
    plot(eixo_bandas_plot, relacao_xy_pot_db(1:num_bandas_finais_plot), 'm.-');
    title('Rela��o Pot. X/Y por Banda');
    xlabel('Frequ�ncia (Hz)');
    ylabel('Rela��o X/Y (dB)'); grid on; xlim([0 max_freq_analise_banda]);
else disp('Dados insuficientes para Gr�fico 5.'); end

% GR�FICO 6: Sinais Completos no Tempo
figure;
if N_efetiva_processar > 0 && ~isempty(y1D) && ~isempty(x1D)
    tempo_eixo_completo = (0:N_efetiva_processar-1)/Fs;
    plot(tempo_eixo_completo, y1D(1:N_efetiva_processar), 'b', ...
         tempo_eixo_completo, x1D(1:N_efetiva_processar), 'r');
    title('Sinais Completos no Tempo');
    xlabel('Tempo (s)'); ylabel('Amplitude Normalizada');
    legend('Sinal Y (Tidal)', 'Sinal X (Spotify)'); ylim([-0.7 0.7]); grid on;
else disp('Dados insuficientes para Gr�fico 6.'); end

fprintf('An�lise conclu�da.\n');