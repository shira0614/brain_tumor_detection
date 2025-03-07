function[] = single_slice_visualization(nii_data)

    slice_idx = round(size(nii_data, 3) / 2); % Seleziona la slice centrale
    figure;
    imshow(nii_data(:,:,slice_idx), []);
    title('Immagine TC - Slice Centrale');
    colormap gray; % Assicura che l'immagine sia in scala di grigi
    colorbar;

end