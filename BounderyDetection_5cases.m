function IC_Browser_AllInOne
% ================================================================
% IC_Browser_AllInOne.m  (refactored, 2025‑04‑20)
% ------------------------------------------------
%  • Browse IC component images by type
%  • Five boundary‑detection modes, switchable with 1–5
%  • ← / → : previous / next image   • q : quit
%  • Each mode shows its own sliders; integer parameters snap to integers
% ================================================================

%% ---------- Default parameters (store in CELL) -----------------
params = cell(5,1);
params{1} = struct('medW',5,'sobThr',0.12,'minA',1500);
params{2} = struct('canLow',0.05,'canHigh',0.15,'closeRad',4,'minA',2000);
params{3} = struct('sigma',5,'zcThr',0.01,'reRad',6,'minSize',1000);   %  ← added minSize
params{4} = struct('diskR',3,'gradThr',35,'minA',2500);
params{5} = struct('cLow',0.05,'cHigh',0.15,'hFrac',0.25,'gap',50,'minL',15);

%% ---------- Slider metadata : {label field min max fmt} --------
meta = cell(5,1);
meta{1} = { ...
    {'Median window','medW',1,15,'%d'}; ...
    {'Sobel threshold','sobThr',0,1,'%.2f'}; ...
    {'Min blob area','minA',100,5000,'%d'}};
meta{2} = { ...
    {'Canny low','canLow',0,1,'%.2f'}; ...
    {'Canny high','canHigh',0,1,'%.2f'}; ...
    {'Close radius','closeRad',1,15,'%d'}; ...
    {'Min blob area','minA',100,5000,'%d'}};
meta{3} = { ...  % ← updated for minSize
    {'LoG sigma','sigma',0.5,10,'%.1f'}; ...
    {'Zero‑cross thr','zcThr',0,0.2,'%.3f'}; ...
    {'Reconstruction rad','reRad',1,15,'%d'}; ...
    {'Min blob area','minSize',100,2000,'%d'}};
meta{4} = { ...
    {'Disk radius','diskR',1,10,'%d'}; ...
    {'Gradient thr','gradThr',0,255,'%d'}; ...
    {'Min blob area','minA',100,5000,'%d'}};
meta{5} = { ...
    {'Canny low','cLow',0,1,'%.2f'}; ...
    {'Canny high','cHigh',0,1,'%.2f'}; ...
    {'Hough peak frac','hFrac',0,1,'%.2f'}; ...
    {'FillGap','gap',0,100,'%d'}; ...
    {'MinLength','minL',10,50,'%d'}};

%% ---------- Pick folder & component type -----------------------
ct = icStruct();
folder = uigetdir(pwd,'Pick IC folder'); if folder==0, return; end
[sel,ok] = listdlg('PromptString','Choose component type:', ...
                   'SelectionMode','single','ListString',{ct.desc});
if ~ok, return; end
TP = ct(sel);

files = strings(TP.count,1);
for k = 1:TP.count
    files(k) = fullfile(folder, sprintf('%s%05d.png',TP.prefix,k));
end
files = files(isfile(files)); nImg = numel(files);
if nImg==0
    errordlg('No images found!'); return;
end

%% ---------- Main figure & shared state -------------------------
mode = 1; idx = 1;   % current mode / image index

hFig = figure('Name','IC Browser','NumberTitle','off', ...
              'KeyPressFcn',@figKey);
setappdata(hFig,'params',params);   % store cell array

hPanel = uipanel(hFig,'Units','normalized', ...
                 'Position',[0 .01 1 .18], 'Title','Parameters');

rebuildSliders(mode);
updateDisplay();
uiwait(hFig);

%% ================= NESTED CALLBACKS ============================
    function figKey(~,evt)
        switch evt.Key
            case 'rightarrow', idx = min(idx+1,nImg);
            case 'leftarrow',  idx = max(idx-1,1);
            case {'1','2','3','4','5'}
                mode = str2double(evt.Key);
                rebuildSliders(mode);
            case 'q'
                close(hFig); return;
        end
        updateDisplay();
    end

    function sliderCB(m,field,fmt,lbl,slider)
        val = get(slider,'Value');
        if fmt(2)=='d'        % integer field → snap
            val = round(val);
            set(slider,'Value',val);
        end
        p = getappdata(hFig,'params'); prm = p{m}; prm.(field)=val; p{m}=prm;
        setappdata(hFig,'params',p);
        set(lbl,'String',sprintf(fmt,val));
        if mode==m, updateDisplay(); end
    end

    function rebuildSliders(m)
        delete(get(hPanel,'Children'));
        info = meta{m}; n = numel(info);
        rowH = 0.8/n;
        for k = 1:n
            y = 0.95 - k*rowH;
            [lab,fld,mn,mx,fmt] = info{k}{:};
            uiText(hPanel,[0.02 y 0.28 0.12],lab);
            val = getappdata(hFig,'params'); val = val{m}.(fld);
            hVal = uiText(hPanel,[0.85 y 0.13 0.12],sprintf(fmt,val));
            slider = uiSlider(hPanel,[0.35 y 0.45 0.12],mn,mx,val);
            if fmt(2)=='d'         % integer field: set SliderStep
                step = 1/(mx-mn);
                set(slider,'SliderStep',[step 5*step]);
            end
            set(slider,'Callback',@(s,~) sliderCB(m,fld,fmt,hVal,s));
        end
        set(hPanel,'Title',sprintf('Mode %d parameters',m));
    end

    function updateDisplay
        Irgb = imread(files(idx));
        prm = getappdata(hFig,'params'); prm = prm{mode};
        BW = boundaryMask(Irgb,mode,prm);
        perim = imdilate(bwperim(BW,4),strel('disk',1));
        RGB = Irgb; RGB(:,:,1) = RGB(:,:,1) + uint8(255*perim);
        imshow(RGB); axis off;
        txt = sprintf('\\color[rgb]{1,1,1}%s | Mode %d | %d / %d',TP.desc,mode,idx,nImg);
        delete(findall(gcf,'Type','annotation','Tag','infoBox'));
        annotation('textbox',[0.01 .93 .6 .06], 'String',txt,'Interpreter','tex', ...
                   'EdgeColor','none','Color','w','FontSize',11,'FontWeight','bold', ...
                   'BackgroundColor',[0 0 0 0.45],'Tag','infoBox');
        drawnow;
    end
end  % ================= END MAIN FUNCTION ========================

%% ================ Helper UI controls ===========================
function h = uiText(parent,pos,str)
    h = uicontrol(parent,'Style','text','Units','normalized','Position',pos, ...
        'String',str,'HorizontalAlignment','left');
end
function h = uiSlider(parent,pos,minv,maxv,val)
    h = uicontrol(parent,'Style','slider','Units','normalized','Position',pos, ...
        'Min',minv,'Max',maxv,'Value',val);
end

%% ================ Boundary extraction engines ==================
function BW = boundaryMask(Irgb,mode,p)
I = rgb2gray(Irgb);
I = double(I);                     % work in double precision
switch mode
    case 1 % Median ▸ Sobel
        W = round(p.medW);
        Im = medfilt2(I,[W W]);
        G = mat2gray(hypot( ...
            imfilter(Im,fspecial('sobel')','replicate'), ...
            imfilter(Im,fspecial('sobel'),'replicate')));
        BW = G>p.sobThr; BW=imclose(BW,strel('disk',3));
        BW = imfill(BW,'holes'); BW = bwareaopen(BW,p.minA);

    case 2 % Canny ▸ closing
        BW = edge(I,'canny',[p.canLow p.canHigh]);
        BW = imclose(BW,strel('disk',p.closeRad)); BW = imfill(BW,'holes');
        BW = bwareaopen(BW,p.minA);

    case 3  % LoG → zero-cross → reconstruction  (tweaked)
    % 1) Pre-smooth
    I_smooth = imgaussfilt(I, p.sigma);

    % 2) LoG kernel
    hsize = 2*ceil(3*p.sigma)+1;
    H     = fspecial('log', hsize, p.sigma);

    % 3) Response  (work with |R| – sign only matters for zero-cross)
    R  = imfilter(I_smooth, H,'replicate');
    t  = p.zcThr * prctile(abs(R(:)),90);       
    BW0 = edge(I_smooth,'zerocross',t,H);

    % 4) Repair small gaps                             
    seC = strel('disk', max(1,round(p.reRad/2)));
    BW1 = imclose(BW0,seC);
    BW1 = imfill(BW1,'holes');                  

    % 5) Opening-by-reconstruction (unchanged)
    seR = strel('disk', p.reRad);
    BW2 = imreconstruct(imerode(BW1,seR), BW1);

    % 6) Size filter  ▸ clear border ▸ pick the most circular blob
    BW3 = bwareaopen(BW2, p.minSize);

    BW4 = imclearborder(BW3);          % strip anything touching the frame
    if any(BW4(:))

        % ----------  choose component with highest circularity ----------
        % Temporary, as other solution is not found
        L      = bwlabel(BW4);
        stats  = regionprops(L,'Area','Perimeter');
        circ   = arrayfun(@(s) 4*pi*s.Area / (s.Perimeter^2), stats);   % 1 = perfect circle
        [~,k]  = max(circ);
        BW     = (L == k);                
        % ---------------------------------------------------------------------

    else                                    % wheel itself touched the frame
        BW = bwpropfilt(BW3,'Eccentricity',1,'smallest');
    end

    case 4 % Morphological gradient
        se = strel('disk',p.diskR);
        G  = imsubtract(imdilate(I,se), imerode(I,se));
        BW = G > p.gradThr;
        BW = bwareaopen(BW, p.minA);

    case 5   % Canny ▸ Hough line mask
        E  = edge(I,'canny',[p.cLow p.cHigh]);
        [H,theta,rho] = hough(E);
        Pk = houghpeaks(H,10000,'Threshold',p.hFrac*max(H(:)),'NHoodSize',[51 51]);
        L  = houghlines(E,theta,rho,Pk,'FillGap',p.gap,'MinLength',p.minL);
        BW = false(size(E));
        for n = 1:numel(L)
            BW = drawLine(BW,L(n).point1,L(n).point2);
        end
        BW = imdilate(BW, strel('disk',3));
    otherwise
        BW = false(size(I));
end
end

function BW = drawLine(BW,p1,p2)
N = max(abs(diff(round([p1; p2]))))+1;
xs = round(linspace(p1(1),p2(1),N));
ys = round(linspace(p1(2),p2(2),N));
xs = max(1,min(xs,size(BW,2))); ys = max(1,min(ys,size(BW,1)));
BW(sub2ind(size(BW),ys,xs)) = true;
end

%% ================= Component definition table ===================
function ct = icStruct()
ct = [ ...
  struct('prefix','CWW_SP_070_000_000_Be_','count',41,'desc','Side‑Beige'); ...
  struct('prefix','CWW_SP_070_000_000_wi_','count',15,'desc','Side‑White'); ...
  struct('prefix','CWW_SP_077_000_000_Oa_','count',15,'desc','Side‑Oak');   ...
  struct('prefix','CWW_TP_070_007_007_Be_','count',40,'desc','Top‑Beige');  ...
  struct('prefix','CWW_TP_070_008_008_wi_','count',40,'desc','Top‑White');  ...
  struct('prefix','CWW_TP_077_007_007_Oa_','count',40,'desc','Top‑Oak');...
  struct('prefix','pieces_##_##_','count',40,'desc','Multiple-Components') 
];
end


%{
gammaValue = 2.5;                              % tweak γ here
lut = uint8(round(interp1([0 10 25 150 255], ...
                          [0 1 100 180 255], 0:255)));
%}