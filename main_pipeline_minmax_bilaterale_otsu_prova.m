%% 1️⃣ Caricare l'immagine TC in 3D
nii_info = niftiinfo('BRATS_001.nii'); % Metadati
nii_data = niftiread('BRATS_001.nii'); % Volume 3D

% Verificare le dimensioni del volume
size_nii = size(nii_data);
disp(['Dimensioni del volume: ', num2str(size_nii)]);

% Se il volume è 4D, selezioniamo il primo frame
if length(size_nii) == 4
    nii_data = nii_data(:,:,:,1);
end

%% Preprocessing: Normalizzazione min max e Filtro Bilaterale
nii_data = double(nii_data); % Converti in double per precisione
nii_data = (nii_data - min(nii_data(:))) / (max(nii_data(:)) - min(nii_data(:))); % Normalizzazione Min-Max

% Applichiamo un filtro bilaterale per ridurre il rumore senza sfocare i bordi
for i = 1:size(nii_data, 3)
    nii_data(:,:,i) = imbilatfilt(nii_data(:,:,i), 0.1, 5);
end

%% 3️⃣ Skull Stripping: Rimuovere il cranio con Otsu
otsu_threshold = graythresh(nii_data); % Metodo Otsu per trovare il valore soglia
brain_mask = nii_data > otsu_threshold; % Crea una maschera per il cervello

% Applica morfologia per pulire la maschera
brain_mask = imfill(brain_mask, 'holes'); % Riempie i buchi
brain_mask = bwareaopen(brain_mask, 500); % Rimuove piccoli artefatti
nii_data(~brain_mask) = 0; % Applica la maschera al volume originale

%% 4️⃣ Segmentazione del Tumore
% Usa il 99° percentile per trovare una soglia dinamica
threshold = prctile(nii_data(:), 99);
tumor_mask = nii_data > threshold;
disp('Valori unici in tumor_mask:');
disp(unique(tumor_mask));

% Verifica quanti pixel sono attivi
num_pixels = sum(tumor_mask(:));
fprintf('Numero di pixel attivi nella maschera del tumore: %d\n', num_pixels);

if num_pixels == 0
    error('Errore: La maschera del tumore è vuota. Prova a regolare il threshold.');
end

%% 5️⃣ Operazioni Morfologiche per Pulire la Segmentazione
tumor_mask = imfill(tumor_mask, 'holes'); % Riempie i buchi interni
tumor_mask = imopen(tumor_mask, strel('sphere', 3)); % Rimuove rumore con apertura morfologica

%% 6️⃣ Calcolo dell'Area del Tumore
voxel_spacing = nii_info.PixelDimensions; % Spaziatura voxel (mm/pixel)
tumor_area_mm2 = num_pixels * (voxel_spacing(1) * voxel_spacing(2));
fprintf('Area stimata del tumore: %.2f mm²\n', tumor_area_mm2);

num_pixels = sum(tumor_mask(:));
fprintf('Numero di pixel attivi nella maschera 3D: %d\n', num_pixels);

if num_pixels < 100
    error('Errore: La maschera del tumore è troppo piccola. Modifica il threshold.');
end

%% 7️⃣ Visualizzazione 3D con Legenda Chiara
figure('Color', 'black', 'Position', [100, 100, 900, 700], 'Name', 'Visualizzazione 3D Tumore');
hold on;

% Visualizza il tessuto cerebrale con trasparenza
brain_surface = isosurface(nii_data, otsu_threshold * 0.8);
p_brain = patch(brain_surface, 'FaceColor', [0.8, 0.8, 0.9], 'EdgeColor', 'none');
p_brain.FaceAlpha = 0.2;  % Cervello molto trasparente

% Visualizza il tumore in rosso brillante
tumor_surface = isosurface(tumor_mask, 0.5);  % Usa 0.5 per catturare meglio i contorni
p_tumor = patch(tumor_surface, 'FaceColor', 'red', 'EdgeColor', 'none');
p_tumor.FaceAlpha = 0.8;  % Tumore più opaco per evidenziarlo

% Migliora la qualità visiva
isonormals(smooth3(tumor_mask), p_tumor);
isonormals(smooth3(nii_data), p_brain);

% Configura illuminazione e visualizzazione
axis equal; view(3);
daspect([1,1,1]);
lighting gouraud;
camlight('headlight');
camlight('right');

% Migliora l'aspetto degli assi
set(gca, 'XColor', 'white', 'YColor', 'white', 'ZColor', 'white');
xlabel('X (mm)', 'Color', 'white'), ylabel('Y (mm)', 'Color', 'white'), zlabel('Z (mm)', 'Color', 'white');
grid on;
set(gca, 'GridColor', [0.3 0.3 0.3]);

% Aggiungi legenda esplicativa
legend([p_tumor, p_brain], 'Tumore', 'Tessuto Cerebrale', 'TextColor', 'white', 'Location', 'northeast');

% Aggiungi titolo con informazioni sulla segmentazione
title(sprintf('Visualizzazione 3D: Volume Tumore = %.2f mm³', num_pixels * prod(voxel_spacing)), ...
      'Color', 'white', 'FontSize', 14);

% Aggiungi testo informativo
dim = [.2 .02 .3 .1];
str = sprintf(['LEGENDA COLORI:\n' ...
              '- ROSSO: Tessuto tumorale (>%d° percentile)\n' ...
              '- GRIGIO: Tessuto cerebrale normale'], 99);
annotation('textbox', dim, 'String', str, 'FitBoxToText', 'on', ...
           'BackgroundColor', [0 0 0], 'Color', 'white', 'EdgeColor', 'white');

% Abilita rotazione interattiva
rotate3d on;

% Opzionale: Visualizzare anche la TC
tc_surface = isosurface(nii_data, threshold * 1.2);
patch(tc_surface, 'FaceColor', 'blue', 'EdgeColor', 'none', 'FaceAlpha', 0.3);
legend('Tumore', 'TC (filtro)');

%% 8️⃣ Controllo 2D: Mostrare una Sezione della Maschera
slice_idx = round(size(tumor_mask, 3) / 2);
figure;
imshow(tumor_mask(:,:,slice_idx), []);
title('Sezione Assiale della Maschera del Tumore');

% Confronto con la ground truth
label_data = niftiread('BRATS_001_label.nii');
label_data = label_data > 0; % si assume che il tumore sia rappresentato da valori = 1

if ~isequal(size(tumor_mask), size(label_data))
    error('Errore: Le dimensioni della segmentazione e della ground truth non corrispondono!');
end

metrics(tumor_mask, label_data)

overlay_visualization(tumor_mask, label_data)


