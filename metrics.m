function[] = metrics(tumor_mask, label_data)

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

end