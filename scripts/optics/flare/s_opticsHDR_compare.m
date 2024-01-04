%% Calculate PSF/OTF using wvf that matches the OI
% Interpolation in isetcam matches the resolution (um/sample) of the default 
% PSF/OTF with the OI resolution. However, this process introduces minor 
% artifacts in the PSF, such as horizontal and vertical streaks, 
% with intensity levels 1e4 to 1e5 times lower than the PSF's peak. 
% While generally not problematic, these artifacts could be noticeable in 
% HDR scenes, particularly in night settings.
%
% A potential solution is to generate a high-resolution OTF in real-time, 
% but this approach is computationally intensive for large scenes. 
% As a temporary workaround, we precalculate the OTF at the OI's resolution 
% and configure the OI accordingly. 
% This method allows oiCompute to bypass the interpolation step.


% Zhenyi, 2023

%%
ieInit;
clear all; close all
%%
s_size = 1024;
flengthM = 4e-3;
fnumber = 2.2;
flengthMM = flengthM*1e3;

pupilMM = (flengthMM)/fnumber;

scene = sceneCreate('point array',s_size,s_size/2);
scene = sceneSet(scene,'fov',30);

d = create_shapes();
wave = 400:10:700;
illPhotons = Energy2Quanta(wave,blackbody(wave,8000,'energy'));

data = bsxfun(@times, d, reshape(illPhotons, [1 1 31]));

scene = sceneSet(scene,'illuminantPhotons',illPhotons);

scene = sceneSet(scene,'photons',data);

scene = sceneAdjustLuminance(scene,'peak',100000);


index = 1;
fig_plot = figure;set(fig_plot, 'AutoResizeChildren', 'off');
for fnumber = 3:5:13
    oi = oiCreate('diffraction limited');

    oi = oiSet(oi,'optics focallength',flengthM);
    oi = oiSet(oi,'optics fnumber',fnumber);

    % oi needs information from scene to figure out the proper resolution.
    oi = oiCompute(oi, scene);
    oi = oiCrop(oi,'border');
    % oiWindow(oi);

    oi = oiSet(oi, 'name','dl');
    ip = piRadiance2RGB(oi,'etime',1);

    rgb = ipGet(ip,'srgb');
    subplot(3,3,index);imshow(rgb);index = index+1;title(sprintf('DL-Fnumber:%d\n',fnumber));

    oi.optics.model = 'shiftinvariant';
    %% Compute with oiComputeFlare

    aperture = [];
    oi_flare = oiComputeFlare(oi,scene,'aperture',aperture);
    oi_flare = oiSet(oi_flare, 'name','flare');
    oi_flare = oiCrop(oi_flare,'border');
    % oiWindow(oi_wvf);

    % oi_wvf = oiSet(oi_wvf,'displaymode','hdr');
    ip_flare = piRadiance2RGB(oi_flare,'etime',1);
    rgb_flare = ipGet(ip_flare,'srgb');
    subplot(3,3,index);imshow(rgb);index = index+1;title(sprintf('Flare-Fnumber:%d\n',fnumber));

    %% match wvf with OI, and compute with oicompute
    wvf = wvfCreate;
    wvf = wvfSet(wvf, 'focal length', flengthMM, 'mm');
    wvf = wvfSet(wvf, 'calc pupil diameter', flengthMM/fnumber);
    nPixels = oiGet(oi, 'size'); nPixels = nPixels(1);
    wvf = wvfSet(wvf, 'spatial samples', nPixels);
    psf_spacingMM = oiGet(oi,'sample spacing','mm');
    lambdaMM = 550*1e-6;
    pupil_spacingMM = lambdaMM * flengthMM / (psf_spacingMM(1) * nPixels);
    wvf = wvfSet(wvf,'field size mm', pupil_spacingMM * nPixels);
    wvf = wvfCompute(wvf);
    wvfSummarize(wvf);

    oi = oiCompute(wvf, scene);
    oi = oiSet(oi, 'name','flare');
    % oiWindow(oi);
    oi = oiCrop(oi,'border');
    ip = piRadiance2RGB(oi,'etime',1);
    rgb = ipGet(ip,'srgb');
    subplot(3,3, index);imshow(rgb);index = index+1;title(sprintf('WVF-Fnumber:%d\n',fnumber));
end



%%
function binary_mask = create_shapes()
    % Create a blank image
    image_size = 1024;
    binary_mask = zeros(image_size, image_size);

    % Draw a circle
    center = [rand(500)+300, 100+rand(500)]; % center of the circle
    radius = 20;
    [x, y] = meshgrid(1:image_size, 1:image_size);
    binary_mask((x - center(1)).^2 + (y - center(2)).^2 <= radius^2) = 1;

    % Draw a rectangle
    top_left = [500, 500];
    width = 100;
    height = 100;
    binary_mask(top_left(1):(top_left(1)+height), top_left(2):(top_left(2)+width)) = 1;

    % % Draw a triangle
    % vertices = [200, 300; 250, 400; 150, 400];
    % binary_mask = insertShape(binary_mask, 'FilledPolygon', vertices(:)', 'Color', 'white', 'Opacity', 1);

    % Draw a hexagon
    center_hex = [750+rand(100), 750+rand(100)];
    size_hex = 50;
    angle = 0:pi/3:2*pi;
    hex_x = center_hex(1) + size_hex * cos(angle);
    hex_y = center_hex(2) + size_hex * sin(angle);
    hexagon = [hex_x; hex_y];
    binary_mask = insertShape(binary_mask, 'FilledPolygon', hexagon(:)', 'Color', 'white', 'Opacity', 1);

    % Convert to binary
    binary_mask = im2bw(binary_mask);

    % Display the image
    % imshow(binary_mask);
end
