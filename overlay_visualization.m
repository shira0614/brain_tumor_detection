function[] = overlay_visualization(tumor_mask, label_data)

    slice_idx = round(size(tumor_mask, 3) / 2); % slice centrale
    
    figure;
    tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % Segmentazione Predetta
    nexttile;
    imshow(tumor_mask(:,:,slice_idx), []);
    title('Segmentazione Predetta', 'FontSize', 12);
    
    % Ground Truth
    nexttile;
    imshow(label_data(:,:,slice_idx), []);
    title('Ground Truth', 'FontSize', 12);
    
    % Overlay tra segmentazione e ground truth
    nexttile;
    overlay = imfuse(tumor_mask(:,:,slice_idx), label_data(:,:,slice_idx), 'blend');
    imshow(overlay);
    title('Confronto Overlay', 'FontSize', 12);
    
    sgtitle('Confronto tra Segmentazione e Ground Truth', 'FontSize', 14);

end