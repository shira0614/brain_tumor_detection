%% 1️⃣ Caricare l'immagine TC in 3D
nii_info = niftiinfo('BRATS_001.nii'); % Metadati
nii_data = niftiread('BRATS_001.nii'); % Volume 3D

% Se il volume è 4D, selezioniamo il primo frame
if ndims(nii_data) == 4
    nii_data = nii_data(:,:,:,1);
end

%% 2️⃣ Preprocessing: Normalizzazione, Equalizzazione e Filtro Bilaterale
nii_data = double(nii_data);
nii_data = (nii_data - min(nii_data(:))) / (max(nii_data(:)) - min(nii_data(:))); % Normalizzazione Min-Max

% Equalizzazione dell'istogramma su ogni fetta 2D (PEGGIORA LE PRESTAZIONI)
for i = 1:size(nii_data, 3)
    nii_data(:,:,i) = adapthisteq(nii_data(:,:,i));
end

% Filtro bilaterale per ridurre il rumore
for i = 1:size(nii_data, 3)
    nii_data(:,:,i) = imbilatfilt(nii_data(:,:,i), 0.1, 5);
end

%% 3️⃣ Skull Stripping: Rimuovere il cranio con Otsu
otsu_threshold = graythresh(nii_data);
brain_mask = nii_data > otsu_threshold;

% Pulizia morfologica
brain_mask = imfill(brain_mask, 'holes');
brain_mask = bwareaopen(brain_mask, 500);
nii_data(~brain_mask) = 0;

%% 4️⃣ Segmentazione del Tumore con Filtro di Canny
threshold = prctile(nii_data(:), 99);
tumor_mask = nii_data > threshold;

% Filtro di Canny per migliorare i bordi della segmentazione
for i = 1:size(tumor_mask, 3)
    edges = edge(tumor_mask(:,:,i), 'Canny');
    tumor_mask(:,:,i) = tumor_mask(:,:,i) | edges;
end

%% 5️⃣ Operazioni Morfologiche per Pulire la Segmentazione
tumor_mask = imfill(tumor_mask, 'holes');
tumor_mask = imopen(tumor_mask, strel('sphere', 3));

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

%% 6️⃣ Caricare la Ground Truth
label_data = niftiread('BRATS_001_label.nii');
label_data = label_data > 0; % Normalizza la label a valori binari

if ~isequal(size(tumor_mask), size(label_data))
    error('Errore: Le dimensioni della segmentazione e della ground truth non corrispondono!');
end

%% 7️⃣ Calcolo delle Metriche
TP = sum((tumor_mask(:) == 1) & (label_data(:) == 1));
FP = sum((tumor_mask(:) == 1) & (label_data(:) == 0));
FN = sum((tumor_mask(:) == 0) & (label_data(:) == 1));
TN = sum((tumor_mask(:) == 0) & (label_data(:) == 0));

DSC = (2 * TP) / (2 * TP + FP + FN);
IoU = TP / (TP + FP + FN);
Sensitivity = TP / (TP + FN);
Specificity = TN / (TN + FP);

fprintf('Risultati della valutazione:\n');
fprintf('→ Dice Similarity Coefficient (DSC): %.4f\n', DSC);
fprintf('→ Jaccard Index (IoU): %.4f\n', IoU);
fprintf('→ Sensibilità (Recall): %.4f\n', Sensitivity);
fprintf('→ Specificità: %.4f\n', Specificity);

figure;
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact'); % Migliora la disposizione

% Primo subplot: Segmentazione Predetta
nexttile;
imshow(tumor_mask(:,:,slice_idx), []);
title('Segmentazione Predetta', 'FontSize', 12);

% Secondo subplot: Ground Truth
nexttile;
imshow(label_data(:,:,slice_idx), []);
title('Ground Truth', 'FontSize', 12);

% Terzo subplot: Overlay tra segmentazione e ground truth
nexttile;
overlay = imfuse(tumor_mask(:,:,slice_idx), label_data(:,:,slice_idx), 'blend');
imshow(overlay);
title('Confronto Overlay', 'FontSize', 12);

% Titolo globale della figura
sgtitle('Confronto tra Segmentazione e Ground Truth', 'FontSize', 14);


