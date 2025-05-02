function diskContourApp
    % Select parent folder
    folder = uigetdir('Select folder containing images');
    if folder == 0, return; end
    
    % Find all matching images recursively
    fileList = dir(fullfile(folder, '**', 'CWW_TP*.png'));
    if isempty(fileList)
        errordlg('No images found matching CWW_TP*.png', 'Error');
        return;
    end
    
    % Create main figure
    fig = figure('Name', 'Disk Contour Analyzer', ...
        'NumberTitle', 'off', ...
        'Units', 'normalized', ...
        'Position', [0.1 0.1 0.8 0.8], ...
        'KeyPressFcn', @keyPressCallback, ...
        'HandleVisibility', 'callback');
    
    % Initialize parameters
    params = struct(...
        'contrastLow', 0.2, ...
        'contrastHigh', 0.8, ...
        'sigma', 1.5, ...
        'threshold', 0.5, ...
        'closeRad', 2, ...
        'openRad', 2);
    
    % Store application data
    data = struct(...
        'fileList', {fileList}, ...
        'currentIdx', 1, ...
        'params', params, ...
        'ax', axes('Position', [0.35 0.3 0.6 0.6]), ...
        'statusLabel', uicontrol('Style', 'text', ...
            'Units', 'normalized', ...
            'Position', [0.35 0.93 0.6 0.04], ...
            'FontSize', 10));
    
    guidata(fig, data);
    
    % Create UI controls
    createUIControls(fig);
    
    % Process initial image
    updateDisplay(fig);
end

function createUIControls(fig)
    % Common control properties
    labelProps = {'Style', 'text', 'Units', 'normalized', 'HorizontalAlignment', 'left'};
    sliderProps = {'Style', 'slider', 'Units', 'normalized', 'Callback', @(src,~) sliderChanged(fig, src)};
    
    % Control positions
    yPos = 0.85;
    vertStep = 0.06;
    
    % Contrast Low
    uicontrol(labelProps{:}, 'Position', [0.05 yPos 0.25 0.04], ...
        'String', 'Contrast Lower Bound (0-1):');
    uicontrol(sliderProps{:}, 'Position', [0.05 yPos-0.04 0.25 0.03], ...
        'Tag', 'contrastLow', 'Min', 0, 'Max', 1, 'Value', 0.2, ...
        'SliderStep', [0.01 0.1]);
    
    % Contrast High
    yPos = yPos - vertStep;
    uicontrol(labelProps{:}, 'Position', [0.05 yPos 0.25 0.04], ...
        'String', 'Contrast Upper Bound (0-1):');
    uicontrol(sliderProps{:}, 'Position', [0.05 yPos-0.04 0.25 0.03], ...
        'Tag', 'contrastHigh', 'Min', 0, 'Max', 1, 'Value', 0.8, ...
        'SliderStep', [0.01 0.1]);
    
    % Sigma
    yPos = yPos - vertStep;
    uicontrol(labelProps{:}, 'Position', [0.05 yPos 0.25 0.04], ...
        'String', 'Gaussian Sigma (0-5):');
    uicontrol(sliderProps{:}, 'Position', [0.05 yPos-0.04 0.25 0.03], ...
        'Tag', 'sigma', 'Min', 0, 'Max', 5, 'Value', 1.5, ...
        'SliderStep', [0.02 0.1]);
    
    % Threshold
    yPos = yPos - vertStep;
    uicontrol(labelProps{:}, 'Position', [0.05 yPos 0.25 0.04], ...
        'String', 'Threshold (0-1):');
    uicontrol(sliderProps{:}, 'Position', [0.05 yPos-0.04 0.25 0.03], ...
        'Tag', 'threshold', 'Min', 0, 'Max', 1, 'Value', 0.5, ...
        'SliderStep', [0.01 0.1]);
    
    % Closing Radius
    yPos = yPos - vertStep;
    uicontrol(labelProps{:}, 'Position', [0.05 yPos 0.25 0.04], ...
        'String', 'Closing Radius (0-10):');
    uicontrol(sliderProps{:}, 'Position', [0.05 yPos-0.04 0.25 0.03], ...
        'Tag', 'closeRad', 'Min', 0, 'Max', 10, 'Value', 2, ...
        'SliderStep', [0.1 0.1]);
    
    % Opening Radius
    yPos = yPos - vertStep;
    uicontrol(labelProps{:}, 'Position', [0.05 yPos 0.25 0.04], ...
        'String', 'Opening Radius (0-10):');
    uicontrol(sliderProps{:}, 'Position', [0.05 yPos-0.04 0.25 0.03], ...
        'Tag', 'openRad', 'Min', 0, 'Max', 10, 'Value', 2, ...
        'SliderStep', [0.1 0.1]);
    
    % Navigation buttons
    uicontrol('Style', 'pushbutton', 'String', '< Previous', ...
        'Units', 'normalized', 'Position', [0.05 0.05 0.1 0.05], ...
        'Callback', @(~,~) navigate(fig, -1));
    uicontrol('Style', 'pushbutton', 'String', 'Next >', ...
        'Units', 'normalized', 'Position', [0.17 0.05 0.1 0.05], ...
        'Callback', @(~,~) navigate(fig, 1));
end

function sliderChanged(fig, src)
    % Update parameters from slider values
    data = guidata(fig);
    tag = get(src, 'Tag');
    data.params.(tag) = get(src, 'Value');
    guidata(fig, data);
    updateDisplay(fig);
end

function navigate(fig, direction)
    % Change current image index
    data = guidata(fig);
    newIdx = data.currentIdx + direction;
    if newIdx > 0 && newIdx <= numel(data.fileList)
        data.currentIdx = newIdx;
        guidata(fig, data);
        updateDisplay(fig);
    end
end

function keyPressCallback(~, event, fig)
    % Handle arrow keys
    switch event.Key
        case 'leftarrow', navigate(fig, -1);
        case 'rightarrow', navigate(fig, 1);
    end
end

function updateDisplay(fig)
    % Main processing and display function
    data = guidata(fig);
    imgPath = fullfile(data.fileList(data.currentIdx).folder, ...
                     data.fileList(data.currentIdx).name);
    
    try
        % Read and preprocess image
        origImg = imread(imgPath);
        grayImg = im2double(rgb2gray(origImg));
        
        % 1. Contrast adjustment
        adjImg = imadjust(grayImg, [data.params.contrastLow, data.params.contrastHigh], []);
        
        % 2. Noise smoothing
        if data.params.sigma > 0
            filterSize = 2*ceil(2*data.params.sigma) + 1;
            gaussFilter = fspecial('gaussian', filterSize, data.params.sigma);
            smoothImg = imfilter(adjImg, gaussFilter, 'replicate');
        else
            smoothImg = adjImg;
        end
        
        % 3. Thresholding
        binImg = smoothImg > data.params.threshold;
        
        % 4. Morphological operations
        if data.params.closeRad > 0
            seClose = strel('disk', round(data.params.closeRad), 0);
            binImg = imclose(binImg, seClose);
        end
        if data.params.openRad > 0
            seOpen = strel('disk', round(data.params.openRad), 0);
            binImg = imopen(binImg, seOpen);
        end
        
        % 5. Find largest connected component
        cc = bwconncomp(binImg);
        stats = regionprops(cc, 'Area', 'BoundingBox', 'Centroid');
        if isempty(stats)
            error('No regions detected');
        end
        [~, maxIdx] = max([stats.Area]);
        boundary = bwboundaries(binImg == maxIdx);
        
        % Display results
        axes(data.ax);
        imshow(origImg);
        hold on;
        plot(boundary{1}(:,2), boundary{1}(:,1), 'r', 'LineWidth', 1.5);
        hold off;
        
        % Update status
        statusStr = sprintf('%s (%d/%d) | C: [%.2f-%.2f] | S: %.1f | T: %.2f | CR: %d | OR: %d', ...
            data.fileList(data.currentIdx).name, data.currentIdx, numel(data.fileList), ...
            data.params.contrastLow, data.params.contrastHigh, data.params.sigma, ...
            data.params.threshold, round(data.params.closeRad), round(data.params.openRad));
        set(data.statusLabel, 'String', statusStr);
        
    catch ME
        axes(data.ax);
        imshow(zeros(100,100,3));
        text(50, 50, 'Processing Error', 'Color', 'r', ...
            'HorizontalAlignment', 'center');
        set(data.statusLabel, 'String', ME.message);
    end
end
