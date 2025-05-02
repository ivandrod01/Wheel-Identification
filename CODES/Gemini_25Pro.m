function diskContourApp()
    % diskContourApp: Interactively process images to find disk contours.
    %
    % Scans a selected folder recursively for images matching 'CWW_TP*.png'.
    % Applies preprocessing (grayscale, contrast, smoothing) suitable for
    % colored disks on a black background. Detects the largest disk boundary
    % and overlays it on the original image. Provides UI controls for parameter
    % tuning and image navigation.
    %
    % NOTE: This version uses standard MATLAB UI components and does NOT
    % require the external "GUI Layout Toolbox" Add-On.

    % --- Constants ---
    APP_TITLE = 'Disk Contour Finder (Standard UI)';
    FILE_PATTERN = 'CWW_TP*.png';
    INITIAL_STATUS = 'Select a folder to begin.';

    % --- Application State Variables ---
    handles = struct(); % Structure to hold UI handles and application data
    handles.imageFiles = []; % List of found image files (struct array from dir)
    handles.currentIndex = 0; % Index of the currently displayed image
    handles.parentFolder = ''; % Path to the selected parent folder

    % --- Default Parameters ---
    handles.params.gaussSigma = 2.0;    % Sigma for Gaussian smoothing
    handles.params.imadjustLowIn = 0.1; % Low input level for imadjust
    handles.params.imadjustHighIn = 0.8;% High input level for imadjust
    handles.params.morphCloseRadius = 5; % Radius for morphological closing disk
    handles.params.minArea = 500;      % Minimum area to keep after morphological opening (bwareaopen)

    % --- Setup UI ---
    createUI(); % Call the UI creation function
    updateStatus(INITIAL_STATUS); % Initial status message

    % Make figure visible after setup
    handles.fig.Visible = 'on';

    % --- Nested Functions (Callbacks and Helpers) ---

    function createUI()
        % Creates the main figure and UI controls using standard components.

        % --- Define Layout Properties (in Pixels) ---
        figWidth = 800;
        figHeight = 600; % Adjusted height slightly
        controlPanelWidth = 210; % Width for the left panel
        statusBarHeight = 25;
        margin = 10; % General margin
        spacing = 8;  % Spacing between controls
        controlHeight = 22; % Standard height for buttons, labels
        sliderHeight = 20;
        labelHeight = 18;

        % --- Main Figure ---
        screenSize = get(groot, 'ScreenSize');
        figX = (screenSize(3) - figWidth) / 2;
        figY = (screenSize(4) - figHeight) / 2;

        handles.fig = figure('Name', APP_TITLE, ...
                             'NumberTitle', 'off', ...
                             'Position', [figX, figY, figWidth, figHeight], ...
                             'MenuBar', 'none', ...
                             'ToolBar', 'none', ...
                             'Visible', 'off', ...
                             'Resize', 'off', ... % Disable resizing for simplicity with pixel layout
                             'CloseRequestFcn', @closeApp, ...
                             'Units', 'pixels'); % Use pixel units

        % --- Controls Panel (Left) ---
        panelX = margin;
        panelY = margin + statusBarHeight;
        panelHeight = figHeight - panelY - margin;
        handles.controlsPanel = uipanel('Parent', handles.fig, ...
                                       'Title', 'Controls', ...
                                       'Units', 'pixels', ...
                                       'Position', [panelX, panelY, controlPanelWidth, panelHeight]);

        % --- Axes (Right) ---
        axesX = panelX + controlPanelWidth + margin;
        axesY = panelY;
        axesWidth = figWidth - axesX - margin;
        axesHeight = panelHeight;
        handles.imgAx = axes('Parent', handles.fig, ...
                             'Units', 'pixels', ...
                             'Position', [axesX, axesY, axesWidth, axesHeight], ...
                             'XTick', [], 'YTick', [], 'Box', 'on');
                             %'LooseInset', get(handles.imgAx,'TightInset')); % Adjust tightness later if needed

        % --- Status Bar (Bottom) ---
        statusBarY = margin;
        handles.statusBar = uicontrol('Parent', handles.fig, 'Style', 'text', ...
                                      'String', INITIAL_STATUS, ...
                                      'Units', 'pixels', ...
                                      'Position', [margin, statusBarY, figWidth - 2*margin, statusBarHeight], ...
                                      'HorizontalAlignment', 'left');

        % --- Populate Controls Panel (Manual Positioning) ---
        panelContentWidth = controlPanelWidth - 2*margin;
        currentY = panelHeight - margin - controlHeight; % Start from top inside panel

        % Folder Selection Button
        uicontrol('Parent', handles.controlsPanel, 'Style', 'pushbutton', ...
                  'String', 'Select Folder', ...
                  'Units', 'pixels', ...
                  'Position', [margin, currentY, panelContentWidth, controlHeight], ...
                  'Callback', @selectFolderCallback);
        currentY = currentY - controlHeight - spacing*2; % Extra spacing after button

        % Parameter Sliders and Labels (Using helper)
        currentY = addSliderManual(handles.controlsPanel, 'Gaussian Sigma:', 0.1, 10, handles.params.gaussSigma, @sliderCallback, 'gaussSigma', currentY, panelContentWidth, margin, spacing);
        currentY = addSliderManual(handles.controlsPanel, 'Contrast Low In:', 0, 1, handles.params.imadjustLowIn, @sliderCallback, 'imadjustLowIn', currentY, panelContentWidth, margin, spacing);
        currentY = addSliderManual(handles.controlsPanel, 'Contrast High In:', 0, 1, handles.params.imadjustHighIn, @sliderCallback, 'imadjustHighIn', currentY, panelContentWidth, margin, spacing);
        currentY = addSliderManual(handles.controlsPanel, 'Morph Close Radius:', 1, 20, handles.params.morphCloseRadius, @sliderCallback, 'morphCloseRadius', currentY, panelContentWidth, margin, spacing);
        currentY = addSliderManual(handles.controlsPanel, 'Min Area Filter:', 50, 5000, handles.params.minArea, @sliderCallback, 'minArea', currentY, panelContentWidth, margin, spacing);

        % Navigation Buttons (Bottom of Panel)
        navButtonWidth = (panelContentWidth - spacing) / 2;
        navButtonY = margin; % Place at the bottom of the panel
        handles.prevButton = uicontrol('Parent', handles.controlsPanel, 'Style', 'pushbutton', ...
                                       'String', 'Previous', ...
                                       'Units', 'pixels', ...
                                       'Position', [margin, navButtonY, navButtonWidth, controlHeight], ...
                                       'Callback', @prevImageCallback, 'Enable', 'off');
        handles.nextButton = uicontrol('Parent', handles.controlsPanel, 'Style', 'pushbutton', ...
                                       'String', 'Next', ...
                                       'Units', 'pixels', ...
                                       'Position', [margin + navButtonWidth + spacing, navButtonY, navButtonWidth, controlHeight], ...
                                       'Callback', @nextImageCallback, 'Enable', 'off');

        % --- Keyboard Shortcuts ---
        set(handles.fig, 'KeyPressFcn', @keyPressCallback);

        % --- Store handles ---
        guidata(handles.fig, handles); % Store handles structure
    end

    function currentY = addSliderManual(parent, labelText, minVal, maxVal, initialVal, callback, paramName, startY, contentWidth, margin, spacing)
        % Helper to add a labeled slider group using manual positioning.
        % Returns the Y position for the *next* control group's top.

        sliderValueLabelWidth = 45; % Width for the numeric value display
        sliderActualWidth = contentWidth - sliderValueLabelWidth - spacing;
        labelInternalY = startY; % Label at the top of the group
        sliderInternalY = labelInternalY - labelHeight; % Slider below label
        sliderGroupHeight = labelHeight + sliderHeight; % Total height of this group

        % Parameter Label
        uicontrol('Parent', parent, 'Style', 'text', 'String', labelText, ...
                  'Units', 'pixels', ...
                  'Position', [margin, labelInternalY, contentWidth, labelHeight], ...
                  'HorizontalAlignment', 'left');

        % Slider Control
        slider = uicontrol('Parent', parent, 'Style', 'slider', ...
                           'Min', minVal, 'Max', maxVal, 'Value', initialVal, ...
                           'Units', 'pixels', ...
                           'Position', [margin, sliderInternalY, sliderActualWidth, sliderHeight], ...
                           'Callback', {@sliderCallbackWrapper, callback, paramName}, ...
                           'Tag', [paramName '_slider']); % Tag for easy access

        % Value Display Label
        valueLabelHandle = uicontrol('Parent', parent, 'Style', 'text', ...
                                   'String', sprintf('%.2f', initialVal), ...
                                   'Units', 'pixels', ...
                                   'Position', [margin + sliderActualWidth + spacing, sliderInternalY, sliderValueLabelWidth, sliderHeight],...
                                   'HorizontalAlignment', 'right', ...
                                   'Tag', [paramName '_label']); % Tag for easy access

        % Store handles for the value label
        handles = guidata(parent); % Get handles structure (figure or panel)
        handles.([paramName '_label']) = valueLabelHandle;
        guidata(parent, handles); % Save handles structure

        % Calculate Y position for the next control group
        currentY = startY - sliderGroupHeight - spacing;
    end

    function sliderCallbackWrapper(sliderObj, ~, mainCallback, paramName)
        % Wrapper to get slider value, update label, and call the main callback.
        % This function remains largely the same.
        handles = guidata(sliderObj); % Get latest handles
        newValue = get(sliderObj, 'Value');

        % Ensure value stays within bounds
        minVal = get(sliderObj, 'Min');
        maxVal = get(sliderObj, 'Max');
        newValue = max(minVal, min(maxVal, newValue)); % Clamp value
        set(sliderObj, 'Value', newValue); % Update slider position if clamped

        % Update the associated text label using stored handle
        valueLabelHandle = handles.([paramName '_label']);
        set(valueLabelHandle, 'String', sprintf('%.2f', newValue));

        % Call the actual processing callback
        mainCallback(sliderObj, [], paramName, newValue);
    end

    function selectFolderCallback(~, ~)
        % Callback for the "Select Folder" button. (Corrected Version)
        handles = guidata(handles.fig); % Get latest handles
        % Use current path if available, otherwise fallback to pwd
        startPath = handles.parentFolder;
        if isempty(startPath) || ~isfolder(startPath)
             startPath = pwd;
        end
        selectedPath = uigetdir(startPath, 'Select Parent Folder Containing Images');

        if selectedPath == 0 % User cancelled
            return;
        end

        handles.parentFolder = selectedPath;
        updateStatus(['Scanning folder: ', selectedPath]);
        drawnow; % Update UI to show status

        % Recursively find image files
        searchPattern = fullfile(selectedPath, '**', FILE_PATTERN);
        handles.imageFiles = dir(searchPattern);

        if isempty(handles.imageFiles)
            warndlg(['No images matching "', FILE_PATTERN, '" found in the selected folder or subfolders.'], 'No Images Found');
            handles.currentIndex = 0;
            set(handles.prevButton, 'Enable', 'off');
            set(handles.nextButton, 'Enable', 'off');
            cla(handles.imgAx); % Clear axes
            title(handles.imgAx, ''); % Clear title
            updateStatus(['No images found in: ', selectedPath]);
        else
            handles.currentIndex = 1; % Start at the first image
            set(handles.prevButton, 'Enable', 'off'); % Can't go back from first image

            % Correctly determine 'Enable' state for Next button
            onOffState = {'off', 'on'};
            nextEnableState = onOffState{ (numel(handles.imageFiles) > 1) + 1 }; % Use logical indexing
            set(handles.nextButton, 'Enable', nextEnableState); % Apply the determined state

            updateStatus(['Found ', num2str(numel(handles.imageFiles)), ' images.']);
            processAndUpdateImage(); % Process and display the first image
        end

        guidata(handles.fig, handles); % Save updated handles
    end

    function sliderCallback(~, ~, paramName, newValue)
        % Callback for parameter sliders. (Remains the same)
        handles = guidata(handles.fig); % Get latest handles
        handles.params.(paramName) = newValue; % Update the parameter
        guidata(handles.fig, handles); % Save updated handles

        % Re-process and update the display if an image is loaded
        if handles.currentIndex > 0 && ~isempty(handles.imageFiles)
             processAndUpdateImage();
        end
    end

    function nextImageCallback(~, ~)
        % Callback for the "Next" button. (Remains the same)
        handles = guidata(handles.fig); % Get latest handles
        if handles.currentIndex < numel(handles.imageFiles)
            handles.currentIndex = handles.currentIndex + 1;
            guidata(handles.fig, handles); % Save updated handles
            updateNavigationButtons();
            processAndUpdateImage();
        end
    end

    function prevImageCallback(~, ~)
        % Callback for the "Previous" button. (Remains the same)
        handles = guidata(handles.fig); % Get latest handles
        if handles.currentIndex > 1
            handles.currentIndex = handles.currentIndex - 1;
            guidata(handles.fig, handles); % Save updated handles
            updateNavigationButtons();
            processAndUpdateImage();
        end
    end

     function keyPressCallback(~, event)
        % Callback for keyboard shortcuts (arrow keys). (Remains the same)
        handles = guidata(handles.fig); % Get latest handles
        switch event.Key
            case 'rightarrow'
                if strcmp(get(handles.nextButton, 'Enable'), 'on')
                    nextImageCallback(handles.nextButton, []);
                end
            case 'leftarrow'
                 if strcmp(get(handles.prevButton, 'Enable'), 'on')
                    prevImageCallback(handles.prevButton, []);
                 end
        end
    end

    function updateNavigationButtons()
        % Enables/disables navigation buttons based on current index. (Corrected Version)
        handles = guidata(handles.fig); % Get latest handles
        numImages = numel(handles.imageFiles);

        % Determine 'on'/'off' state using logical conditions
        onOffState = {'off', 'on'}; % Cell array for states

        prevEnableState = onOffState{ (handles.currentIndex > 1) + 1 }; % Index 1 ('off') if false, Index 2 ('on') if true
        set(handles.prevButton, 'Enable', prevEnableState);

        nextEnableState = onOffState{ (handles.currentIndex < numImages) + 1 }; % Index 1 ('off') if false, Index 2 ('on') if true
        set(handles.nextButton, 'Enable', nextEnableState);
    end

    function updateStatus(message)
        % Updates the text in the status bar. (Remains the same)
        set(handles.statusBar, 'String', message);
    end

    function processAndUpdateImage()
        % Reads, processes the current image, and updates the display.
        % This core processing logic remains the same.
        handles = guidata(handles.fig); % Get latest handles

        if handles.currentIndex == 0 || isempty(handles.imageFiles)
             cla(handles.imgAx);
             title(handles.imgAx, 'No image selected');
             updateStatus('Load images first.');
             return;
        end

        currentFile = handles.imageFiles(handles.currentIndex);
        imgPath = fullfile(currentFile.folder, currentFile.name);
        updateStatus(['Processing: ', currentFile.name]);
        drawnow;

        try
            % --- 1. Read Original Image ---
            imgOriginal = imread(imgPath);

            % --- 2. Pre-processing ---
            % Convert to grayscale
            if size(imgOriginal, 3) == 3
                imgGray = rgb2gray(imgOriginal);
            else
                imgGray = imgOriginal; % Already grayscale
            end

            % Adjust contrast using current slider values
            low_in = max(0, min(1, handles.params.imadjustLowIn));
            high_in = max(0, min(1, handles.params.imadjustHighIn));
            if low_in >= high_in
                if high_in > 0.1
                    low_in = high_in - 0.1;
                else
                    low_in = 0;
                    high_in = 0.1;
                end
                 low_in = max(0, low_in); % Re-clamp
            end
            imgAdjusted = imadjust(imgGray, [low_in, high_in], []); % Auto output range

            % Noise smoothing before edge detection
            sigma = max(0.1, handles.params.gaussSigma); % Ensure sigma is positive
            imgSmoothed = imgaussfilt(imgAdjusted, sigma);

            % --- 3. Edge Detection ---
            imgEdges = edge(imgSmoothed, 'canny');

            % --- 4. Morphological Operations ---
            closeRadius = round(handles.params.morphCloseRadius);
            closeRadius = max(1, closeRadius);
            seClose = strel('disk', closeRadius);
            imgClosed = imclose(imgEdges, seClose);

            imgFilled = imfill(imgClosed, 'holes');

            minAreaSize = round(handles.params.minArea);
            minAreaSize = max(1, minAreaSize);
            imgCleaned = bwareaopen(imgFilled, minAreaSize);

            % --- 5. Find Largest Blob Boundary ---
            cc = bwconncomp(imgCleaned);
            stats = regionprops(cc, 'Area', 'PixelIdxList');

            largestArea = 0;
            largestBlobIndex = 0;
            if cc.NumObjects > 0
                [largestArea, largestBlobIndex] = max([stats.Area]);
            end

            boundary = [];
            if largestBlobIndex > 0 && largestArea > 0
                largestBlobMask = false(size(imgCleaned));
                largestBlobMask(stats(largestBlobIndex).PixelIdxList) = true;
                boundaries = bwboundaries(largestBlobMask, 'noholes');
                if ~isempty(boundaries)
                    boundary = boundaries{1};
                end
            else
                 updateStatus(['Warning: No significant blob found for ', currentFile.name]);
            end

            % --- 6. Display Results ---
            imshow(imgOriginal, 'Parent', handles.imgAx);
            hold(handles.imgAx, 'on');
            if ~isempty(boundary)
                plot(handles.imgAx, boundary(:,2), boundary(:,1), 'r', 'LineWidth', 2);
            end
            hold(handles.imgAx, 'off');

            % --- 7. Update Title ---
            paramStr = sprintf('Sigma:%.1f, Adj:[%.2f-%.2f], CloseR:%d, MinArea:%d', ...
                sigma, low_in, high_in, closeRadius, minAreaSize);
            title(handles.imgAx, ...
                  {sprintf('File: %s (%d/%d)', currentFile.name, handles.currentIndex, numel(handles.imageFiles)), ...
                   paramStr}, ...
                  'Interpreter', 'none');


        catch ME
            errorMsg = sprintf('Error processing image %s:\n%s', imgPath, ME.message);
            errordlg(errorMsg, 'Processing Error');
            updateStatus(['Error processing: ', currentFile.name]);
             cla(handles.imgAx);
             title(handles.imgAx, {'Error loading/processing image', currentFile.name}, 'Interpreter', 'none');
        end
        drawnow; % Ensure UI updates immediately
    end

    function closeApp(~, ~)
        % Clean up and close the figure. (Remains the same)
        delete(handles.fig);
    end

end % End of main diskContourApp function