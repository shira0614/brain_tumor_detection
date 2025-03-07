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

%% 2️⃣ Preprocessing: Normalizzazione Min-Max e Filtro Bilaterale
nii_data = double(nii_data);
ii_data = (nii_data - min(nii_data(:))) / (max(nii_data(:)) - min(nii_data(:))); % Normalizzazione

for i = 1:size(nii_data, 3)
    nii_data(:,:,i) = imbilatfilt(nii_data(:,:,i), 0.1, 5);
end

%% 3️⃣ Skull Stripping: Rimozione del Cranio con Otsu
otsu_threshold = graythresh(nii_data);
brain_mask = nii_data > otsu_threshold;
brain_mask = imfill(brain_mask, 'holes');
brain_mask = bwareaopen(brain_mask, 500);
ii_data(~brain_mask) = 0;

%% 4️⃣ Segmentazione del Tumore con Region Growing
% Selezione di un punto seme manualmente o automaticamente
[x, y, z] = ind2sub(size(nii_data), find(nii_data == max(nii_data(:)), 1)); % Punto più luminoso
seed = [x, y, z];

% Parametri per l'espansione della regione
intensity_threshold = 0.2; % Permette un range di intensità
connectivity = 26; % Consideriamo la connettività 3D massima

% Applicazione del Region Growing
tumor_mask = false(size(nii_data));
tumor_mask(seed(1), seed(2), seed(3)) = true;
tumor_mask = imdilate(tumor_mask, strel('sphere', 2)); % Espansione iniziale

while true
    new_region = imdilate(tumor_mask, strel('sphere', 1)) & ~tumor_mask;
    new_region = new_region & (nii_data > (nii_data(seed(1), seed(2), seed(3)) - intensity_threshold)) & ...
                           (nii_data < (nii_data(seed(1), seed(2), seed(3)) + intensity_threshold));
    if ~any(new_region(:))
        break;
    end
    tumor_mask = tumor_mask | new_region;
end

%% 5️⃣ Pulizia della Segmentazione
% Rimozione delle piccole componenti e riempimento buchi
if sum(tumor_mask(:)) < 100
    error('Errore: La maschera del tumore è troppo piccola. Modifica il threshold.');
end
tumor_mask = imfill(tumor_mask, 'holes');
tumor_mask = imopen(tumor_mask, strel('sphere', 3));

%% 6️⃣ Calcolo dell'Area e Volume del Tumore
voxel_spacing = nii_info.PixelDimensions;
tumor_volume_mm3 = sum(tumor_mask(:)) * prod(voxel_spacing);
fprintf('Volume stimato del tumore: %.2f mm³\n', tumor_volume_mm3);

%% 7️⃣ Visualizzazione 3D
figure('Color', 'black');
hold on;
p_tumor = patch(isosurface(tumor_mask, 0.5), 'FaceColor', 'red', 'EdgeColor', 'none');
p_tumor.FaceAlpha = 0.8;
axis equal; view(3); lighting gouraud; camlight;
title(sprintf('Segmentazione Tumore: Volume = %.2f mm³', tumor_volume_mm3), 'Color', 'white');

%% 8️⃣ Confronto con la Ground Truth
label_data = niftiread('BRATS_001_label.nii');
label_data = label_data > 0;

% Calcolo metriche di valutazione
TP = sum((tumor_mask(:) == 1) & (label_data(:) == 1));
FP = sum((tumor_mask(:) == 1) & (label_data(:) == 0));
FN = sum((tumor_mask(:) == 0) & (label_data(:) == 1));
DSC = (2 * TP) / (2 * TP + FP + FN);

fprintf('DSC: %.4f\n', DSC);

