close all 

%% 1️⃣ Caricare l'immagine TC in 3D
nii_info = niftiinfo('./data/BRATS_001.nii'); % Metadati
nii_data = niftiread('./data/BRATS_001.nii'); % Volume 3D

% Verificare le dimensioni del volume
size_nii = size(nii_data);
disp(['Dimensioni del volume: ', num2str(size_nii)]);

% Se il volume è 4D, selezioniamo il primo frame
if length(size_nii) == 4
    nii_data = nii_data(:,:,:,1);
end

single_slice_visualization(nii_data)

%% 2️⃣ Preprocessing: Normalizzazione min-max e Filtro Bilaterale
nii_data = double(nii_data);
nii_data = (nii_data - min(nii_data(:))) / (max(nii_data(:)) - min(nii_data(:))); % Normalizzazione Min-Max

% Filtro bilaterale per ridurre il rumore preservando i bordi
for i = 1:size(nii_data, 3)
    nii_data(:,:,i) = imbilatfilt(nii_data(:,:,i), 0.1, 5);
end

%% 4️⃣ Segmentazione del Tumore con K-Means
num_clusters = 3; % Numero di cluster (tumore, tessuti sani, sfondo...)
nii_vector = nii_data(:);
[idx, centers] = kmeans(nii_vector, num_clusters, 'Replicates', 3);

% Determinare quale cluster corrisponde al tumore (il valore più alto)
[~, tumor_cluster] = max(centers);
tumor_mask = reshape(idx == tumor_cluster, size(nii_data));

%% 5️⃣ Pulizia della Segmentazione
tumor_mask = imfill(tumor_mask, 'holes');
tumor_mask = imopen(tumor_mask, strel('sphere', 3));

% Controllo se la segmentazione ha pixel significativi
num_pixels = sum(tumor_mask(:));
fprintf('Numero di pixel attivi nella maschera del tumore: %d\n', num_pixels);

if num_pixels < 100
    error('Errore: La maschera del tumore è troppo piccola. Prova a regolare i cluster.');
end

%% 6️⃣ Calcolo dell'Area del Tumore
voxel_spacing = nii_info.PixelDimensions;
tumor_area_mm2 = num_pixels * (voxel_spacing(1) * voxel_spacing(2));
fprintf('Area stimata del tumore: %.2f mm²\n', tumor_area_mm2);

%% 7️⃣ Visualizzazione 3D con Legenda Chiara
figure('Color', 'black', 'Position', [100, 100, 900, 700], 'Name', 'Visualizzazione 3D Tumore');
hold on;

% Visualizza il tumore in rosso brillante
tumor_surface = isosurface(tumor_mask, 0.5);
p_tumor = patch(tumor_surface, 'FaceColor', 'red', 'EdgeColor', 'none');
p_tumor.FaceAlpha = 0.8;

% Miglioramenti visivi
isonormals(smooth3(tumor_mask), p_tumor);
axis equal; view(3);
daspect([1,1,1]);
lighting gouraud;
camlight('headlight');
camlight('right');

% Etichette
xlabel('X (mm)', 'Color', 'white'), ylabel('Y (mm)', 'Color', 'white'), zlabel('Z (mm)', 'Color', 'white');
grid on;
set(gca, 'GridColor', [0.3 0.3 0.3]);

% Legenda
legend([p_tumor], 'Tumore', 'TextColor', 'white', 'Location', 'northeast');
title(sprintf('Visualizzazione 3D: Volume Tumore = %.2f mm³', num_pixels * prod(voxel_spacing)), ...
      'Color', 'white', 'FontSize', 14);
rotate3d on;

% Confronto con la ground truth
label_data = niftiread('./data/BRATS_001_label.nii');
label_data = label_data > 0;

if ~isequal(size(tumor_mask), size(label_data))
    error('Errore: Le dimensioni della segmentazione e della ground truth non corrispondono!');
end

metrics(tumor_mask, label_data)

overlay_visualization(tumor_mask, label_data)
