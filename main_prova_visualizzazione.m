% 1️⃣ Caricare l'immagine TC in 3D
nii_info = niftiinfo('BRATS_001.nii'); % Metadati
nii_data = niftiread('BRATS_001.nii'); % Volume 3D

% Controllare le dimensioni del volume
size_nii = size(nii_data);
disp(['Dimensioni del volume:', num2str(size_nii)]);

% Se il volume è 4D (es. [x, y, z, t]), selezioniamo il primo frame
if length(size_nii) == 4
    nii_data = nii_data(:,:,:,1); % Prendere solo il primo frame
end

% Creare la maschera binaria (rivediamo il thresholding)
threshold = prctile(nii_data(:), 99); % Usa il 99° percentile invece del massimo
tumor_mask = nii_data > threshold;

% Assicurarci che sia 3D
if ndims(tumor_mask) ~= 3
    error('Errore: La maschera del tumore non è 3D.');
end

% Verifica quanti pixel sono attivi nella maschera
num_pixels = sum(tumor_mask(:));
fprintf('Numero di pixel attivi nella maschera: %d\n', num_pixels);

if num_pixels == 0
    error('Errore: La maschera del tumore è vuota. Verifica il thresholding.');
end

% Ora possiamo eseguire isosurface senza errori
tumor_surface = isosurface(tumor_mask, 0.5);
patch(tumor_surface, 'FaceColor', 'red', 'EdgeColor', 'none');


% 3️⃣ Creare un modello 3D del tumore con isosurface
figure;
hold on;
tumor_surface = isosurface(tumor_mask, 0.5);
patch(tumor_surface, 'FaceColor', 'red', 'EdgeColor', 'none');

% 4️⃣ Impostare la visualizzazione
axis equal; % Assi proporzionati
view(3); % Vista 3D
camlight; lighting phong; % Effetti di luce per migliorare la resa
xlabel('X'), ylabel('Y'), zlabel('Z');
title('Ricostruzione 3D del Tumore');

% 5️⃣ Opzionale: Mostrare anche la TC con isocaps
tc_surface = isosurface(nii_data, threshold * 1.2);
% Cambia la trasparenza e la luce per migliorare la visibilità
patch(tumor_surface, 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 0.7);
camlight; lighting gouraud; % Migliore illuminazione

slice_idx = round(size(tumor_mask, 3) / 2); % Prendi una fetta centrale
imshow(tumor_mask(:,:,slice_idx), []);
title('Sezione assiale della maschera del tumore');

