function diskContourApp
    % Initialize the GUI
    fig = figure('Name', 'Disk Contour Detection', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 600]);

    % Create an axes for displaying the image
    ax = axes('Parent', fig, 'Position', [0.1, 0.3, 0.8, 0.6]);

    % UI Elements
    uicontrol('Style', 'text', 'String', 'Current File:', 'Position', [10, 570, 100, 20]);
    fileText = uicontrol('Style', 'text', 'String', '', 'Position', [120, 570, 800, 20]);

    uicontrol('Style', 'text', 'String', 'Frame Number:', 'Position', [10, 540, 100, 20]);
    frameText = uicontrol('Style', 'text', 'String', '', 'Position', [120, 540, 100, 20]);

    uicontrol('Style', 'text', 'String', 'Threshold:', 'Position', [10, 510, 100, 20]);
    thresholdSlider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0.5, 'Position', [120, 510, 200, 20], 'Callback', @updatePreview);
    thresholdText = uicontrol('Style', 'text', 'String', '0.5', 'Position', [330, 510, 50, 20]);

    uicontrol('Style', 'pushbutton', 'String', 'Previous', 'Position', [10, 480, 100, 20], 'Callback', @previousImage);
    uicontrol('Style', 'pushbutton', 'String', 'Next', 'Position', [120, 480, 100, 20], 'Callback', @nextImage);

    % Initialize variables
    imageFiles = {};
    currentIndex = 1;
    threshold = 0.5;

    % Select parent folder
    parentFolder = uigetdir(pwd, 'Select Parent Folder');
    if isequal(parentFolder, 0)
        errordlg('No folder selected. Exiting.', 'Error');
        return;
    end

    % Recursively find images matching the pattern
    imageFiles = dir(fullfile(parentFolder, '**', 'CWW_TP*.png'));
    if isempty(imageFiles)
        errordlg('No images found matching the pattern.', 'Error');
        return;
    end

    % Display the first image
    updatePreview();

    % Nested functions for callbacks
    function updatePreview(~, ~)
        % Update threshold value
        threshold = get(thresholdSlider, 'Value');
        set(thresholdText, 'String', num2str(threshold));

        % Read and preprocess the image
        imgPath = fullfile(imageFiles(currentIndex).folder, imageFiles(currentIndex).name);
        img = imread(imgPath);
        grayImg = rgb2gray(img);
        contrastImg = imadjust(grayImg);
        smoothedImg = medfilt2(contrastImg, [3 3]);

        % Thresholding
        binaryImg = imbinarize(smoothedImg, threshold);

        % Morphological operations
        se = strel('disk', 5);
        binaryImg = imclose(binaryImg, se);
        binaryImg = imopen(binaryImg, se);

        % Find the largest connected component
        cc = bwconncomp(binaryImg);
        numPixels = cellfun(@numel, cc.PixelIdxList);
        [~, idx] = max(numPixels);
        binaryImg = false(size(binaryImg));
        binaryImg(cc.PixelIdxList{idx}) = true;

        % Overlay the boundary on the original image
        boundary = bwperim(binaryImg);
        overlayImg = img;
        overlayImg(repmat(boundary, [1 1 3])) = 0; % Set boundary pixels to black first
        overlayImg(:,:,1) = overlayImg(:,:,1) + uint8(boundary) * 255; % Add red component

        % Display the image
        imshow(overlayImg, 'Parent', ax);

        % Update file and frame information
        set(fileText, 'String', imageFiles(currentIndex).name);
        set(frameText, 'String', num2str(currentIndex));
    end

    function previousImage(~, ~)
        if currentIndex > 1
            currentIndex = currentIndex - 1;
            updatePreview();
        end
    end

    function nextImage(~, ~)
        if currentIndex < length(imageFiles)
            currentIndex = currentIndex + 1;
            updatePreview();
        end
    end
end
