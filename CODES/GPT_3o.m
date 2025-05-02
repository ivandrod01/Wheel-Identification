%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% diskContourApp.m
% Interactive viewer to locate the single coloured wooden
% wheel (white / beige / oak) on a black background.
% ----------------------------------------------------------
%  * Recursively scans a user‑chosen parent folder for files
%    matching the pattern  'CWW_TP*.png'.
%  * Provides two sliders (binary threshold & minimum area
%    fraction) and Prev/Next buttons or ←/→ arrow shortcuts.
%  * Each UI action re‑processes ONLY the current image – the
%    UI elements stay visible; imshow never overwrites them.
%  * Processing pipeline (commented below) is optimised for a
%    single, mostly circular disk on a dark background.
% ----------------------------------------------------------
%  Author: ChatGPT · April 2025
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function diskContourApp

    %%-------------------------------------------------------
    % 1. Ask the user where the image collection lives
    %%-------------------------------------------------------
    startDir = uigetdir(pwd,'Select the parent folder that contains CWW_TP*.png');
    if startDir==0                      % user pressed Cancel
        return;
    end

    %%-------------------------------------------------------
    % 2. Collect every matching image *recursively*
    %%-------------------------------------------------------
    imgFiles = dir(fullfile(startDir,'**','CWW_TP*.png'));
    if isempty(imgFiles)
        errordlg('No images that match the pattern "CWW_TP*.png" were found.','No Images');
        return;
    end
    nFiles   = numel(imgFiles);
    idx      = 1;                       % current image index

    %%-------------------------------------------------------
    % 3. Default algorithm parameters (editable via sliders)
    %%-------------------------------------------------------
    params.binThresh    = 0.32;         % upper Canny threshold  ∈ [0,1]
    params.minAreaFrac  = 0.01;         % keep blobs ≥ x·imageArea (also ∈ [0,1])

    %%-------------------------------------------------------
    % 4. Build an uncluttered UI (figure, axes, sliders & buttons)
    %%-------------------------------------------------------
    hFig = figure('Name',buildTitle(), ...
                  'NumberTitle','off', ...
                  'Toolbar','none', ...
                  'MenuBar','none', ...
                  'Color',[0.2 0.2 0.2]);

    hAx  = axes('Parent',hFig);         % main display axes

    %––– Slider : Binary threshold ––––––––––––––––––––––––
    uicontrol(hFig,'Style','text','String','BinThresh', ...
                    'Units','normalized','Position',[0.02 0.02 0.12 0.04]);
    s1 = uicontrol(hFig,'Style','slider','Min',0,'Max',1, ...
                   'Value',params.binThresh,'Units','normalized', ...
                   'Position',[0.15 0.02 0.3 0.04], ...
                   'Callback',@updateBinThresh);

    %––– Slider : Minimum area fraction –––––––––––––––––––
    uicontrol(hFig,'Style','text','String','MinAreaFrac', ...
                    'Units','normalized','Position',[0.52 0.02 0.14 0.04]);
    s2 = uicontrol(hFig,'Style','slider','Min',0,'Max',0.2, ...
                   'Value',params.minAreaFrac,'Units','normalized', ...
                   'Position',[0.67 0.02 0.3 0.04], ...
                   'Callback',@updateAreaFrac);

    %––– Navigation buttons –––––––––––––––––––––––––––––––
    uicontrol(hFig,'Style','pushbutton','String','<< Prev', ...
                    'Units','normalized','Position',[0.02 0.90 0.1 0.05], ...
                    'Callback',@prevImage);
    uicontrol(hFig,'Style','pushbutton','String','Next >>', ...
                    'Units','normalized','Position',[0.88 0.90 0.1 0.05], ...
                    'Callback',@nextImage);

    set(hFig,'WindowKeyPressFcn',@keyPress);   % ← / → shortcuts

    %%-------------------------------------------------------
    % 5. Show the first image immediately
    %%-------------------------------------------------------
    showImage();

    %–––––––––––––––––––––––––––––––––––––––––––––––––––––––
    %                 Nested / Callback Functions          –
    %–––––––––––––––––––––––––––––––––––––––––––––––––––––––

    function showImage()
        % Read and analyse the current frame, then overlay the
        % detected boundary onto the original RGB image.
        fname   = fullfile(imgFiles(idx).folder,imgFiles(idx).name);
        Iorig   = imread(fname);

        %––––– 5.1  Pre‑processing ––––––––––––––––––––––––
        %   • Convert to grayscale                               (disk is lighter)
        %   • Contrast‑stretch to maximise dynamic range         (imadjust)
        %   • Gaussian smooth to suppress isolated bright noise  (σ=1)
        Igray   = imgaussfilt(imadjust(rgb2gray(Iorig)),1);

        %––––– 5.2  Edge detection (Canny) ––––––––––––––––––
        hiThr   = params.binThresh;                 % user‑set upper threshold
        loThr   = max(0.4*hiThr,0.01);              % keep low threshold ≥1 % to avoid zero
        edges   = edge(Igray,'Canny',[loThr hiThr]);

        %––––– 5.3  Morphology to fill the disk –––––––––––––
        se      = strel('disk',3);
        bw      = imdilate(edges,se);               % thicken ridges
        bw      = imfill(bw,'holes');               % close interior
        bw      = imopen(bw,se);                    % remove tiny spurs

        %––––– 5.4  Keep ONLY the largest valid blob ––––––––
        CC      = bwconncomp(bw,8);
        boundary = [];
        if CC.NumObjects>0
            stats   = regionprops(CC,'Area','PixelIdxList');
            areas   = [stats.Area];
            minA    = params.minAreaFrac * numel(bw);
            areas(areas<minA) = 0;                  % zero‑out undersized blobs
            if any(areas)
                [~,ii] = max(areas);                % unique wheel ⇒ biggest area
                bw     = false(size(bw));
                bw(stats(ii).PixelIdxList) = true;
                B       = bwboundaries(bw,'noholes');
                boundary = B{1};
            end
        end

        %––––– 5.5  Display ––––––––––––––––––––––––––––––––
        cla(hAx);
        imshow(Iorig,'Parent',hAx);
        hold(hAx,'on');
        if ~isempty(boundary)
            plot(hAx,boundary(:,2),boundary(:,1),'r','LineWidth',2);
        end
        hold(hAx,'off');
        title(hAx,buildTitle(),'Interpreter','none','Color','w');
    end

    %%–––––––– Slider Callbacks ––––––––––––––––––––––––––––
    function updateBinThresh(src,~)
        params.binThresh = max(0,min(1,get(src,'Value'))); % clamp to [0,1]
        showImage();
    end

    function updateAreaFrac(src,~)
        params.minAreaFrac = max(0,min(0.2,get(src,'Value'))); % clamp to [0,0.2]
        showImage();
    end

    %%–––––––– Navigation –––––––––––––––––––––––––––––––––
    function prevImage(~,~)
        idx = idx - 1; if idx<1, idx = nFiles; end, showImage();
    end

    function nextImage(~,~)
        idx = idx + 1; if idx>nFiles, idx = 1; end, showImage();
    end

    function keyPress(~,evt)
        switch evt.Key
            case 'leftarrow',  prevImage();
            case 'rightarrow', nextImage();
        end
    end

    %%–––––––– Utility ––––––––––––––––––––––––––––––––––––
    function txt = buildTitle()
        txt = sprintf('diskContourApp  |  %s  (%d/%d)  |  Bin=%.2f  MinA=%.3f', ...
                       imgFiles(idx).name,idx,nFiles, ...
                       params.binThresh,params.minAreaFrac);
    end
end
