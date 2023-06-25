%%  More experiments with flare
% 
% See also v_wvf which might be moved here or renamed v_wvfFlare
%

%% Experiment with different wavefronts

% We can start with any Zernike coefficients
wvf = wvfCreate;
% fieldsize = wvfGet(wvf,'fieldsizemm');
% wvf = wvfSet(wvf,'fieldsizemm',2*fieldsize);
wvf = wvfSet(wvf,'calc pupil diameter',3);
wvf = wvfSet(wvf,'wave',550);
wvf = wvfSet(wvf,'focal length',0.017);

% wvf = wvfSet(wvf,'zcoeffs',0.5,{'defocus'});
% wvf = wvfSet(wvf,'zcoeffs',-2,{'vertical_astigmatism'});

% There are many parameters on this function, including dot mean, line
% mean, dot sd, line sd, line opacity.  They are returned in params
nsides = 3;
[pupilAmp, params] = wvfPupilAmplitude(wvf,'nsides',nsides,...
    'dot mean',20, 'dot sd',3, 'dot opacity',0.5, ...
    'line mean',20, 'line sd', 2, 'line opacity',0.5);
% ieNewGraphWin; imagesc(pupilAmp); colormap(gray); axis image

wvf = wvfPupilFunction(wvf,'amplitude',pupilAmp);
wvf = wvfComputePSF(wvf);
wvfPlot(wvf,'psf','um',550,10,'airy disk');

%{
ieNewGraphWin([], 'wide');
subplot(1,2,1); wvfPlot(wvf,'image pupil amp','um',550,'no window');
subplot(1,2,2); wvfPlot(wvf,'image pupil phase','um',550,'no window');
%}

%% Calculate the oi from the scene, but using the wvf

oi = wvfApply(scene,wvf);
oi = oiSet(oi,'name','wvf');

% Show the PSF
%{
oiPlot(oi,'psf550');
set(gca,'xlim',[-10 10],'ylim',[-10 10]);
%}

oi = oiCrop(oi,'border');
oiWindow(oi);
oiSet(oi,'gamma',0.5);

%% The same scene through piFlareApply

% wvfGet(wvf,'calc pupil diameter','mm')
[oi, pMask, psf] = piFlareApply(scene,'num sides aperture',nsides, ...
    'focal length',wvfGet(wvf,'focal length','m'), ...
    'fnumber',wvfGet(wvf,'fnumber'));
oi = oiSet(oi,'name','flare');
oiWindow(oi);

%%
ieNewGraphWin;
mesh(getMiddleMatrix(psf(:,:,15),30));

% piFlareApply does not put the proper OTF information in the optical
% image. Therefore, this plot is not correct.  The photons, though,
% are approximately correct.
%{
 oiPlot(oi,'psf550');
 set(gca,'xlim',[-10 10],'ylim',[-10 10]);
%}

% Now with a little defocus
wvf = wvfCreate;
wvf = wvfSet(wvf,'zcoeffs',0.5,{'defocus'});
wvf = wvfComputePSF(wvf);
wvfPlot(wvf,'psf','um',550,20);

%{
ieNewGraphWin([], 'wide');
subplot(1,3,1); wvfPlot(wvf,'image pupil amp','um',550,'no window');
subplot(1,3,2); wvfPlot(wvf,'image pupil phase','um',550,'no window');
subplot(1,3,3); wvfPlot(wvf,'image wavefront aberrations','um',550,'no window');
%}


% sceneWindow(scene);



%% HDR Test scene
% Uses sceneHDRLights
% {
scene = sceneCreate('hdr');
scene = sceneSet(scene,'fov',2);
sceneWindow(scene);
%}
%%
oi = wvfApply(scene,wvf);
oi = oiSet(oi,'name','wvf');

oiWindow(oi);
oiSet(oi,'render flag','hdr');
%%

%% The same scene through piFlareApply

% wvfGet(wvf,'calc pupil diameter','mm')
[oi, pMask, psf] = piFlareApply(scene,'num sides aperture',nsides, ...
    'focal length',wvfGet(wvf,'focal length','m'), ...
    'fnumber',wvfGet(wvf,'fnumber'));
oi = oiSet(oi,'name','flare');
oiWindow(oi);

%%
ieNewGraphWin;
mesh(getMiddleMatrix(psf(:,:,15),30));

% piFlareApply does not put the proper OTF information in the optical
% image. Therefore, this plot is not correct.  The photons, though,
% are approximately correct.
%{
 oiPlot(oi,'psf550');
 set(gca,'xlim',[-10 10],'ylim',[-10 10]);
%}
