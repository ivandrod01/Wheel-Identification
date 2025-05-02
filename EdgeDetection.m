function Wheel_Browser
% ================================================================
% Wheel_Browser.m  ·  Wheel & Multi‑component browser
% ------------------------------------------------
%  • Load Folder  – choose directory & wheel type any time
%  • Debug View   – toggle ROI + circles panel (wheel mode)
%  • Mode popup   – “Wheel” | “Multi”    (shortcut: key m)
%  • Keys         – ← / →  previous / next image   |   q quit
% ------------------------------------------------
%  Sliders (bottom panel):  closeR | σ | thr | sens | minA
%  Constant scale: 0.6494 mm / px   (trained)
% ================================================================

SCALE_MM_PER_PX = 0.6494;           % <-- fixed mm per pixel

% ---------- default parameters ---------------------------------
P = struct('pad',0,'thick',5,'sigma',1.2,'thr',0.22, ...
           'closeR',3,'sens',0.92,'minA',800);
params = {P};

meta = {{ ...
    {'Close radius','closeR',1,10,'%d'}; ...
    {'Gaussian σ'  ,'sigma' ,0,5 ,'%.1f'}; ...
    {'Prewitt thr' ,'thr'   ,0,1 ,'%.2f'}; ...
    {'Hough sens'  ,'sens'  ,0.85,0.98,'%.2f'}; ...
    {'Min area'    ,'minA'  ,100,5000,'%d'}}};

modeNames = ["Wheel" "Multi"];   debugON = true;

% ---------- GUI skeleton ---------------------------------------
hFig = figure('Name','Wheel Browser','NumberTitle','off','KeyPressFcn',@keyCB);

uicontrol('Style','pushbutton','String','Load Folder','Units','normalized', ...
    'Position',[0.01 0.95 0.12 0.04],'Callback',@loadFolder);

hMode = uicontrol('Style','popupmenu','String',modeNames,'Units','normalized', ...
    'Position',[0.14 0.95 0.1 0.04],'Callback',@modePopup);



hPanel = uipanel(hFig,'Units','normalized','Position',[0 .01 1 .18],'Title','Parameters');

setappdata(hFig,'params',params);

% run‑time variables
mode=1; idx=1; files=[]; nImg=0; TP=[];

loadFolder();                  % initial prompt
uiwait(hFig);                  % keep GUI alive

%% ---------- callbacks ------------------------------------------
    function keyCB(~,evt)
        switch evt.Key
            case 'rightarrow', idx=min(idx+1,nImg);
            case 'leftarrow',  idx=max(idx-1,1);
            case 'm',          mode = 3-mode; set(hMode,'Value',mode);
            case 'q',          close(hFig); return;
        end
        drawFrame();
    end

    function modePopup(src,~)
        mode = src.Value; drawFrame();
    end

    

    function loadFolder(~,~)
        folder = uigetdir(pwd,'Pick image folder');
        if folder==0, return; end
        ct = icStruct();
        [sel,ok] = listdlg('PromptString','Choose wheel type:', ...
                           'SelectionMode','single','ListString',{ct.desc});
        if ~ok, return; end
        TP = ct(sel);

        % ---------- build file list (pattern‑only version) --------------
        L     = dir(fullfile(folder, TP.pattern));   % wildcard grab
        files = fullfile(folder, {L.name});
        files = files(isfile(files));                % keep existing only
        nImg  = numel(files);
        if nImg==0, errordlg('No images found!'); return; end
        idx = 1; buildSliders(); drawFrame();
    end

    function sliderCB(fld,fmt,lbl,src)
        v = get(src,'Value');
        if fmt(2)=='d', v = round(v); set(src,'Value',v); end
        p = getappdata(hFig,'params'); p{1}.(fld) = v; setappdata(hFig,'params',p);
        set(lbl,'String',sprintf(fmt,v)); drawFrame();
    end

    function buildSliders
        delete(get(hPanel,'Children'));
        info = meta{1}; n = numel(info); rh = .85/n;
        for k = 1:n
            y = .95 - k*rh; [lab,fld,mn,mx,fmt] = info{k}{:};
            uiText(hPanel,[.02 y .28 .12],lab);
            v = params{1}.(fld);
            hVal = uiText(hPanel,[.85 y .13 .12],sprintf(fmt,v));
            s = uiSlider(hPanel,[.35 y .45 .12],mn,mx,v);
            if fmt(2)=='d', st = 1/(mx-mn); set(s,'SliderStep',[st 5*st]); end
            set(s,'Callback',@(src,~) sliderCB(fld,fmt,hVal,src));
        end
    end

    function drawFrame
        if isempty(files), return; end
        if isstring(files)                 % string array → convert
    fname = char(files(idx));      % string → char row vector
else                               % cell array of char
    fname = files{idx};
end
Irgb = imread(fname);
        prm  = getappdata(hFig,'params'); prm = prm{1};

        if mode==1
            [BWo,BWi,diam,ctr] = detectWheel(Irgb,prm);
            showWheel(Irgb,BWo,BWi,diam,prm,ctr,true,SCALE_MM_PER_PX, ...
                      idx,nImg,TP.desc);
        else
            stats = detectMulti(Irgb,prm);
            showMulti(Irgb,stats,idx,nImg,TP.desc);
        end
    end
end  % ---------------- END MAIN ---------------------------------

%% -------- detectWheel ------------------------------------------
function [BWo,BWi,diam,ctr] = detectWheel(Irgb,prm)
% Quick‑n‑dirty wheel detector. Steps are pretty much what you'd do by hand
% but scripted:
%   1) Shrink to grayscale and optionally blur to calm down sensor noise.
%   2) Run a Prewitt edge filter, then binarise with a user‑tweakable
%      threshold. The slider labelled "thr" in the GUI nudges that.
%   3) Clean up the spaghetti edges with a disk closing (closeR slider).
%   4) Flood‑fill the thing so we get one solid blob – hopefully the wheel.
%   5) Use regionprops for a first guess on centre & radius. That’s just to
%      crop a tighter ROI before we throw imfindcircles at it (much faster).
%   6) imfindcircles hunts for the bright outside rim and the darker hub.
%      We keep only the biggest/closest match because false positives love
%      to party in there.
%   7) Finally build two binary masks: BWo for the outer rim, BWi for the
%      inner hub. diam comes back in *pixels* so the caller can scale it.

Igray = rgb2gray(Irgb);                           % 1) to grayscale
if prm.sigma > 0
    Iflt = imgaussfilt(Igray,prm.sigma);          % optional blur
else
    Iflt = Igray;
end
Id  = im2double(adapthisteq(uint8(Iflt)));        % local contrast boost
hp  = fspecial('prewitt');
Mag = mat2gray(hypot(imfilter(Id,hp','replicate'), ...
                     imfilter(Id,hp,'replicate'))); % 2) edge magnitude
BWedge = imclose(bwmorph(Mag>prm.thr,'clean'), ... % 3) threshold + clean
                 strel('disk',prm.closeR));
BW1    = bwareafilt(imfill(imclose(BWedge,strel('disk',4)),'holes'),1);

BWo=false(size(Igray)); BWi=BWo; diam=[NaN NaN]; ctr=[NaN NaN];
if ~any(BW1(:)), return; end                      % bail out if nothing

S   = regionprops(BW1,'BoundingBox','EquivDiameter','Centroid');
r0  = S.EquivDiameter/2;                          % rough radius guess
bb  = S.BoundingBox; ctr = S.Centroid;
ROI = Iflt(round(bb(2)):round(bb(2)+bb(4)), ...   % tight crop around blob
           round(bb(1)):round(bb(1)+bb(3)));

% Hough radii search ranges – sized around r0 but with wiggle room
outerR = max(round([.8 1.2]*r0),6);
innerR = max(round([6 .3*r0]),6);
% Bright outer rim ----------------------------------------------
[centO,radO] = imfindcircles(ROI,outerR,'ObjectPolarity','bright', ...
                              'Sensitivity',prm.sens,'EdgeThreshold',0.03);
% Dark inner hub -------------------------------------------------
[centI,radI] = imfindcircles(ROI,innerR,'ObjectPolarity','dark', ...
                              'Sensitivity',0.93,'EdgeThreshold',0.02);
% Weed out extras – keep the beefiest outer, nearest inner -------
if numel(radO) > 1
    [~,k] = max(radO); radO = radO(k); centO = centO(k,:);
end
if isempty(radO), return; end                     % no rim, no wheel
if numel(radI) > 1
    d = hypot(centI(:,1)-centO(1),centI(:,2)-centO(2));
    [~,k] = min(d); radI = radI(k); centI = centI(k,:);
end

% Build the masks in image coordinates --------------------------
[X,Y] = meshgrid(1:size(Igray,2),1:size(Igray,1));
xc = centO(1)+bb(1)-1; yc = centO(2)+bb(2)-1; r = radO;
BWo = hypot(X-xc,Y-yc) <= r; diam(1) = 2*r;
if ~isempty(radI)
    xc = centI(1)+bb(1)-1; yc = centI(2)+bb(2)-1; r = radI;
    BWi = hypot(X-xc,Y-yc) <= r; diam(2) = 2*r;
end
end

%% -------- showWheel --------------------------------------------
function showWheel(Irgb,BWo,BWi,diam,prm,ctr,dbg,SCALE,idx,nImg,label)
% Draw the pretty picture for wheel mode. Nothing fancy – just a big axes
% on the left for the full image with red/blue outlines, plus an optional
% zoom‑in box on the right when debug view is on.
%   * perO/perI = perimeter (fat) masks painted red & blue so they shine.
%   * Title shows diameters in px and converted to mm with that magic
%     SCALE constant.
%   * If dbg flag is true we crop a little square around the wheel centre
%     (with 10 px padding) and overlay the same outlines so you can eyeball
%     detection quality.

persistent axMain axROI
if isempty(axMain) || ~isvalid(axMain)
    axMain = axes('Parent',gcf,'Position',[0 0 0.75 1]);
end
cla(axMain,'reset');

perO = imdilate(bwperim(BWo,4),strel('disk',prm.thick-1)); % chunky red
perI = imdilate(bwperim(BWi,4),strel('disk',prm.thick-1)); % chunky blue
RGB  = Irgb;
RGB(:,:,1)=RGB(:,:,1)+uint8(255*perO);                     % paint R
RGB(:,:,3)=RGB(:,:,3)+uint8(255*perI);                     % paint B
imshow(RGB,'Parent',axMain); axis(axMain,'off');

outer_mm = diam(1)*SCALE; inner_mm = diam(2)*SCALE;
title(axMain,sprintf('[%s] %d/%d   D_o %.1fpx = %.2fmm   D_i %.1fpx = %.2fmm', ...
      label,idx,nImg,diam(1),outer_mm,diam(2),inner_mm),'Interpreter','tex');

% ROI preview (circle ±10 px)
if dbg && all(~isnan([ctr diam(1)]))
    if isempty(axROI) || ~isvalid(axROI)
        axROI = axes('Parent',gcf,'Position',[0.76 0.05 0.23 0.9]);
    end
    cla(axROI,'reset');
    pad = 10; r = diam(1)/2; [H,W,~] = size(Irgb);
    x1 = max(1, round(ctr(1)-r-pad)); x2 = min(W, round(ctr(1)+r+pad));
    y1 = max(1, round(ctr(2)-r-pad)); y2 = min(H, round(ctr(2)+r+pad));
    roiRGB = Irgb(y1:y2,x1:x2,:);
    roiO   = BWo(y1:y2,x1:x2);
    roiI   = BWi(y1:y2,x1:x2);
    imshow(roiRGB,'Parent',axROI); hold(axROI,'on');
    visboundaries(axROI,roiO,'Color','r');          % outer red
    visboundaries(axROI,roiI,'Color','b');          % inner blue
    hold(axROI,'off'); axis(axROI,'off'); title(axROI,'ROI + circles');
elseif ~isempty(axROI) && isvalid(axROI)
    cla(axROI,'reset');
end
end

%% -------- detectMulti ------------------------------------------
function stats = detectMulti(Irgb,prm)
% Multi‑component detector for side/assembly pics we just want bounding boxes and a rough colour tag.
% Pipeline:
%   1) Same grayscale + optional blur + adaptive hist‑eq as before.
%   2) Edge mag via Prewitt, threshold with "thr" slider.
%   3) Morph clean + fill – gives us blobs for *all* pieces.
%   4) regionprops to grab area, bbox, centroid. chuck away tiny ones using
%      minA slider.
%   5) For each blob, sample the median HSV and put it into a 3‑colour
%      bucket: white / beige / brown. Good enough for QA screenshots.

Igray = rgb2gray(Irgb);
if prm.sigma > 0
    Iflt = imgaussfilt(Igray,prm.sigma);
else
    Iflt = Igray;
end
Id  = im2double(adapthisteq(uint8(Iflt)));
hp  = fspecial('prewitt');
Mag = mat2gray(hypot(imfilter(Id,hp','replicate'),imfilter(Id,hp,'replicate')));
BW  = imclose(bwmorph(Mag>prm.thr,'clean'), strel('disk',prm.closeR));
BW  = imfill(imclose(BW,strel('disk',4)),'holes');
CC  = bwconncomp(BW);
stats = regionprops(CC,'Area','BoundingBox','PixelIdxList','Centroid');
stats = stats([stats.Area] >= prm.minA);   % filter small crumbs

% attach simple colour class ------------------------------------
for k = 1:numel(stats)
    bb = stats(k).BoundingBox;
    roi = Irgb(round(bb(2)):round(bb(2)+bb(4)), ...
               round(bb(1)):round(bb(1)+bb(3)), :);
    stats(k).color = classifyColor(roi);
end
end

function clr = classifyColor(rgbROI)
h = rgb2hsv(im2double(rgbROI));
H = median(h(:,:,1),'all'); S = median(h(:,:,2),'all'); V = median(h(:,:,3),'all');
if S < .15 && V > .8
    clr = "white";
elseif H>0.05 && H<0.15 && S<.4 && V>.6
    clr = "beige";
else
    clr = "brown";
end
end

%% -------- showMulti --------------------------------------------
function showMulti(Irgb,stats,idx,nImg,label)
persistent axMainM axThumb                       % survive between calls

% main axis (left 75 %)
if isempty(axMainM) || ~isvalid(axMainM)
    axMainM = axes('Parent',gcf,'Position',[0 0 0.75 1]);
end
cla(axMainM,'reset');
imshow(Irgb,'Parent',axMainM); axis(axMainM,'off');

pal = struct("white",[1 1 1],"beige",[.95 .8 .45],"brown",[.55 .3 .1]);

for k = 1:numel(stats)
    clr = pal.(stats(k).color);
    rectangle(axMainM,'Position',stats(k).BoundingBox,'EdgeColor',clr,'LineWidth',1.5);
    text(stats(k).BoundingBox(1),stats(k).BoundingBox(2)-6, ...
        sprintf('#%d  %s',k,stats(k).color),'Color',clr,'FontWeight','bold');
end
title(axMainM,sprintf('[multi] %s  %d/%d  %d components', ...
      label,idx,nImg,numel(stats)));

% thumbnail bottom‑right (always recreated / updated)
if isempty(axThumb) || ~isvalid(axThumb)
    axThumb = axes('Parent',gcf,'Position',[0.78 0.05 0.2 0.2]);
end
cla(axThumb,'reset');
imshow(Irgb,'Parent',axThumb); axis(axThumb,'off');
end

%% -------- UI helpers -------------------------------------------
function h = uiText(p,pos,str)
h = uicontrol(p,'Style','text','Units','normalized','Position',pos, ...
              'String',str,'HorizontalAlignment','left');
end
function h = uiSlider(p,pos,mn,mx,val)
h = uicontrol(p,'Style','slider','Units','normalized','Position',pos, ...
              'Min',mn,'Max',mx,'Value',val);
end

%% -------- wheel‑type table -------------------------------------
function ct = icStruct()
% --- each entry needs ONLY `pattern` and `desc`
ct = [ ...
  struct('pattern','CWW_TP_070_007_007_Be_*.png', 'desc','Top‑Beige'); ...
  struct('pattern','CWW_TP_070_008_008_wi_*.png', 'desc','Top‑White'); ...
  struct('pattern','CWW_TP_077_007_007_Oa_*.png', 'desc','Top‑Oak');  ...
  struct('pattern','CWW_SP_*_CW_*.png',           'desc','Side‑Position'); ...
  struct('pattern','pieces_##_##_*.png',              'desc','Multiple‑Components'); ...
  struct('pattern','Assem_##_##_*.png',               'desc','Assembly‑Components') ...
];
end
