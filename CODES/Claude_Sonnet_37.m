function diskContourApp()
    % diskContourApp - An application for detecting disk boundaries in images
    % This application scans for images matching 'CWW_TP*.png', processes them
    % to detect disk boundaries, and provides interactive sliders for parameter adjustment.
    
    % Initialize the main figure and UI components
    fig = figure('Name', 'Disk Contour Detection', 'NumberTitle', 'off', ...
        'Position', [100, 100, 1000, 700], 'Resize', 'on');
    
    % Initialize variables
    currentImageIdx = 1;
    imageFiles = {};
    currentPattern = 'CWW_TP*.png';
    
    % Create UI panels
    controlPanel = uipanel('Title', 'Controls', 'Position', [0.01, 0.01, 0.25, 0.98]);
    imagePanel = uipanel('Title', 'Image Preview', 'Position', [0.27, 0.01, 0.72, 0.98]);
    
    % Create axes for image display
    ax = axes('Parent', imagePanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
    
    % Create UI components for folder selection
    uicontrol('Parent', controlPanel, 'Style', 'text', 'String', 'Select Folder:', ...
        'Position', [10, 650, 150, 20], 'HorizontalAlignment', 'left');
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', 'Browse...', ...
        'Position', [10, 620, 100, 25], 'Callback', @selectFolder);
    
    % Text display for current folder
    folderText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
        'String', 'No folder selected', 'Position', [10, 580, 230, 40], ...
        'HorizontalAlignment', 'left');
    
    % Parameter sliders
    % Gaussian blur sigma
    uicontrol('Parent', controlPanel, 'Style', 'text', 'String', 'Gaussian Blur (σ):', ...
        'Position', [10, 550, 150, 20], 'HorizontalAlignment', 'left');
    
    blurSlider = uicontrol('Parent', controlPanel, 'Style', 'slider', ...
        'Min', 0.1, 'Max', 5, 'Value', 1.8, 'Position', [10, 530, 200, 20], ...
        'Callback', @processImage);
    
    blurValueText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
        'String', '1.5', 'Position', [210, 530, 40, 20]);
    
    % Edge detection threshold
    uicontrol('Parent', controlPanel, 'Style', 'text', 'String', 'Edge Threshold:', ...
        'Position', [10, 490, 150, 20], 'HorizontalAlignment', 'left');
    
    threshSlider = uicontrol('Parent', controlPanel, 'Style', 'slider', ...
        'Min', 0, 'Max', 1, 'Value', 0.4, 'Position', [10, 470, 200, 20], ...
        'Callback', @processImage);
    
    threshValueText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
        'String', '0.3', 'Position', [210, 470, 40, 20]);
    
    % Morphological operations size
    uicontrol('Parent', controlPanel, 'Style', 'text', 'String', 'Morph Ops Size:', ...
        'Position', [10, 430, 150, 20], 'HorizontalAlignment', 'left');
    
    morphSlider = uicontrol('Parent', controlPanel, 'Style', 'slider', ...
        'Min', 1, 'Max', 20, 'Value', 3, 'Position', [10, 410, 200, 20], ...
        'Callback', @processImage);
    
    morphValueText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
        'String', '3', 'Position', [210, 410, 40, 20]);
    
    % Minimum area threshold slider
    uicontrol('Parent', controlPanel, 'Style', 'text', 'String', 'Min Area (pixels²):', ...
        'Position', [10, 370, 150, 20], 'HorizontalAlignment', 'left');
    
    areaSlider = uicontrol('Parent', controlPanel, 'Style', 'slider', ...
        'Min', 1000, 'Max', 10000, 'Value', 1000, 'Position', [10, 350, 200, 20], ...
        'Callback', @processImage);
    
    areaValueText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
        'String', '10000', 'Position', [210, 350, 40, 20]);
    
    % Navigation buttons
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', '< Previous', ...
        'Position', [10, 310, 100, 25], 'Callback', @prevImage);
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', 'Next >', ...
        'Position', [120, 310, 100, 25], 'Callback', @nextImage);
    
    % Image information display
    imageInfoText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
        'String', 'No images loaded', 'Position', [10, 250, 230, 50], ...
        'HorizontalAlignment', 'left');
    
    % Setup key press callback for navigation
    set(fig, 'KeyPressFcn', @keyPress);
    
    % Callback function for folder selection
    function selectFolder(~, ~)
        folderPath = uigetdir('', 'Select Folder with Images');
        if folderPath ~= 0
            % Update folder text
            folderText.String = folderPath;
            
            % Find all matching image files
            imageFiles = dir(fullfile(folderPath, currentPattern));
            
            % Check if any images were found
            if isempty(imageFiles)
                msgbox(['No images matching the pattern "', currentPattern, '" found in the selected folder.'], 'No Images Found', 'warn');
                imageInfoText.String = 'No images found';
                return;
            end
            
            % Reset to first image
            currentImageIdx = 1;
            
            % Update image info
            imageInfoText.String = sprintf('Pattern: %s\nImage %d of %d', ...
                currentPattern, currentImageIdx, length(imageFiles));
            
            % Process and display the first image
            processImage();
        end
    end
    
    % Function to process the current image
    function processImage(~, ~)
        % Check if images are loaded
        if isempty(imageFiles)
            return;
        end
        
        try
            % Get current parameter values
            blurSigma = blurSlider.Value;
            edgeThresh = threshSlider.Value;
            morphSize = round(morphSlider.Value);
            minArea = round(areaSlider.Value);
            
            % Update value text displays
            blurValueText.String = num2str(blurSigma, '%.1f');
            threshValueText.String = num2str(edgeThresh, '%.2f');
            morphValueText.String = num2str(morphSize);
            areaValueText.String = num2str(minArea);
            
            % Load the current image
            imgPath = fullfile(imageFiles(currentImageIdx).folder, imageFiles(currentImageIdx).name);
            img = imread(imgPath);
            
            % Convert to grayscale if necessary
            if size(img, 3) == 3
                grayImg = rgb2gray(img);
            else
                grayImg = img;
            end
            
            % Apply contrast enhancement using histogram equalization
            enhancedImg = histeq(grayImg);
            
            % Apply Gaussian blur to reduce noise
            smoothedImg = imgaussfilt(enhancedImg, blurSigma);
            
            % Edge detection using Canny
            edgeImg = edge(smoothedImg, 'Canny', edgeThresh);
            
            % Morphological operations to close gaps
            se = strel('disk', morphSize);
            closedImg = imclose(edgeImg, se);
            
            % Fill holes in the binary image
            filledImg = imfill(closedImg, 'holes');
            
            % Find connected components (blobs)
            cc = bwconncomp(filledImg);
            stats = regionprops(cc, 'Area', 'Perimeter', 'Centroid', 'BoundingBox');
            
            % If no blobs found, show a message
            if isempty(stats)
                imshow(img, 'Parent', ax);
                title(ax, 'No disk detected - try adjusting parameters');
                return;
            end
            
            % Find the blob with the largest area that meets the minimum area threshold
            areas = [stats.Area];
            validIdx = find(areas >= minArea);
            
            if isempty(validIdx)
                imshow(img, 'Parent', ax);
                title(ax, 'No valid disk detected - try reducing minimum area');
                return;
            end
            
            [~, maxIdx] = max(areas(validIdx));
            largestBlobIdx = validIdx(maxIdx);
            
            % Create a mask for the largest blob
            largestBlobMask = false(size(filledImg));
            largestBlobMask(cc.PixelIdxList{largestBlobIdx}) = true;
            
            % Find the boundary of the largest blob
            boundary = bwboundaries(largestBlobMask);
            
            % Display the original image
            imshow(img, 'Parent', ax);
            hold(ax, 'on');
            
            % Plot the boundary of the disk
            if ~isempty(boundary)
                plot(ax, boundary{1}(:,2), boundary{1}(:,1), 'r', 'LineWidth', 2);
            end
            
            % Add the bounding box
            bbox = stats(largestBlobIdx).BoundingBox;
            rectangle(ax, 'Position', bbox, 'EdgeColor', 'g', 'LineWidth', 2);
            
            hold(ax, 'off');
            
            % Update the figure title with image info and parameters
            title(ax, sprintf('%s (%d/%d) - Blur: %.1f, Thresh: %.2f, Morph: %d, MinArea: %d', ...
                imageFiles(currentImageIdx).name, currentImageIdx, length(imageFiles), ...
                blurSigma, edgeThresh, morphSize, minArea), 'Interpreter', 'none');
            
        catch e
            % Display error message
            msgbox(['Error processing image: ', e.message], 'Error', 'error');
        end
    end
    
    % Function to navigate to the previous image
    function prevImage(~, ~)
        if ~isempty(imageFiles) && currentImageIdx > 1
            currentImageIdx = currentImageIdx - 1;
            imageInfoText.String = sprintf('Pattern: %s\nImage %d of %d', ...
                currentPattern, currentImageIdx, length(imageFiles));
            processImage();
        end
    end
    
    % Function to navigate to the next image
    function nextImage(~, ~)
        if ~isempty(imageFiles) && currentImageIdx < length(imageFiles)
            currentImageIdx = currentImageIdx + 1;
            imageInfoText.String = sprintf('Pattern: %s\nImage %d of %d', ...
                currentPattern, currentImageIdx, length(imageFiles));
            processImage();
        end
    end
    
    % Function to handle key presses for navigation
    function keyPress(~, event)
        switch event.Key
            case 'leftarrow'
                prevImage();
            case 'rightarrow'
                nextImage();
        end
    end
end