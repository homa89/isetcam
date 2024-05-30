function oi = opticsPSF(oi,scene,aperture,wvf,varargin)
% Apply the opticalImage using the PSF method to the photon data
%
% Synopsis
%    oi = opticsPSF(oi,scene,varargin);
%
% Inputs
%   oi
%  scene
%
% Optional key/val
%  aperture
%  wvf
%  padvalue
%
% Return
%   oi
%
% Description
%  FIX FIX
%   The optical transform function (OTF) associated with the optics in
%   the OI is applied to the scene data.  This function is called for
%   shift-invariant and diffraction-limited models.  It is not called
%   for the ray trace calculation, which uses the (ray trace method)
%   pointspreads derived from Zemax.
%
%   The OTF data are spectral and thus can be rather large.  The
%   spectral OTF represents every spatial frequency in every waveband.
%
%   The programming issues concerning using Matlab to apply the OTF to the
%   image (rather than convolution in the space domain) are explained
%   below.
%
% See also
%  oiCalculateOTF, oiCompute
%
% Copyright ImagEval Consultants, LLC, 2005.

%% Parse

varargin = ieParamFormat(varargin);
p = inputParser;
p.KeepUnmatched = true;

p.addRequired('oi',@(x)(isstruct(x) && isequal(x.type,'opticalimage')));
p.addRequired('scene',@(x)(isstruct(x) && isequal(x.type,'scene')));

if ieNotDefined('aperture'), aperture = []; end
if ieNotDefined('wvf'), wvf = []; end

p.addParameter('padvalue','zero',@(x)(ischar(x) || isvector(x)));

p.parse(oi,scene,varargin{:});

%%
optics      = oiGet(oi,'optics');
opticsModel = opticsGet(optics,'model');

switch lower(opticsModel)
    case {'skip','skipotf'}
        irradianceImage = oiGet(oi,'photons');
        oi = oiSet(oi,'photons',irradianceImage);
        
    case {'dlmtf','diffractionlimited','shiftinvariant','custom','humanotf'}
        oi = oiApplyPSF(oi,scene,aperture,wvf,'mm',p.Results.padvalue);
        
    otherwise
        error('Unknown OTF method');
end

end

%-------------------------------------------
function oi = oiApplyPSF(oi,scene,aperture,wvf,unit,padvalue)
%Calculate and apply the otf waveband by waveband
%
%   oi = oiApplyPSF(oi,method,unit);
%
% We calculate the OTF every time, never saving it, because it can take up
% a lot of space and is not that hard to calculate.  Also, any change to
% the optics properties would make us recompute the OTF, and keeping things
% synchronized can be error prone.
%
% Example:
%    oi = oiApplyPSF(oi);
%
% Copyright ImagEval Consultants, LLC, 2003.
 
% Input handling
if ieNotDefined('oi'),     error('Optical image required.'); end
if ieNotDefined('aperture'), aperture = [];  end
if ieNotDefined('wvf'),           wvf = [];  end
if ieNotDefined('unit'),         unit = 'mm';end

% Pad the optical image to allow for light spread.  Also, make sure the row
% and col values are even.
imSize   = oiGet(oi,'size');
padSize  = round(imSize/8);
padSize(3) = 0;
sDist = sceneGet(scene,'distance');

% ISETBio and ISETCam, historically, used different padding
% strategies.  Apparently, we have zero, mean and border implemented -
% which are not all documented at the top.  We should also allow spd
% and test it. Zero photons was the default for ISETCam, and mean
% photons was the default for ISETBio.  
% 
% This update is being tested as of 9/25/2023.
switch padvalue
    case 'zero'
        padType = 'zero photons';
    case 'mean'
        padType = 'mean photons'; 
    case 'border'
        padType = 'border photons'; 
    case 'spd'
        error('spd padvalue not yet implemented.')
    otherwise
        error('Unknown padvalue %s',padvalue);
end

oi = oiPadValue(oi,padSize,padType,sDist);

% Convert the oi into the wvf format and compute the PSF
wavelist  = oiGet(oi,'wave');
flength   = oiGet(oi,'focal length',unit);
fnumber   = oiGet(oi,'f number');

% WVF is square.  Use the larger of the two sizes
oiSize    = max(oiGet(oi,'size'));   

% It is possible to get here without having a wvf structure stored with the
% optics of the oi.  But we think that is a case that should be flagged
% explicitly as an error, rather than making up a wvf which might specify
% different optics from what is in the OTF field of the optics structure.
%
% 4/22/24 DHB Made this an error.
if isempty(wvf)
    if (isfield(oi,'optics') & isfield(oi.optics,'wvf'))
        wvf = oi.optics.wvf;
    else
        error('Trying to apply PSF method with an empty passed wvf structure and no wvf field in the oi''s optics. This should not happen.');
    end
    %wvf = wvfCreate('wave',wavelist);
end

% Make sure the wvf matches how the person set the oi/optics info
wvf = wvfSet(wvf, 'focal length', flength, unit);
wvf = wvfSet(wvf, 'calc pupil diameter', flength/fnumber);
wvf = wvfSet(wvf, 'wave',wavelist);
wvf = wvfSet(wvf, 'spatial samples', oiSize);

% Setting this matches the pupil sample spacing with the oi sample
% spacing.
%
% BW: Worried about the lambdaM fixed value.
psf_spacing = oiGet(oi,'sample spacing',unit);

% Default measurement wavelength is 550 nm.
lambdaM = wvfGet(wvf, 'measured wl', 'm');

lambdaUnit = ieUnitScaleFactor(unit)*lambdaM;

% Calculate the pupil sample spacing.
pupil_spacing    = lambdaUnit * flength / (psf_spacing(1) * oiSize); % in meters

% Account for different unit scale, scale the user input unit to mm, 
% This set only takes mm for now.
currentUnitScale = ieUnitScaleFactor(unit);
mmUnitScale      = 1000/currentUnitScale;
wvf = wvfSet(wvf,'field size mm', pupil_spacing * oiSize * mmUnitScale); % only accept mm

% Compute the PSF.  We may need to consider LCA and other parameters
% at this point.  It should be possible to set this true easily.
% if ~isempty(wvf.customLCA)
%     % For now, human is the only option
%     if strcmp(wvf.customLCA,'human')
%         wvf = wvfCompute(wvf,'aperture',aperture,'human lca',true);
%     end
% else
%     % customLCA is empty
%     wvf = wvfCompute(wvf,'aperture',aperture,'human lca',false);
% end
wvf = wvfCompute(wvf,'aperture',aperture);

% Make this work:  wvfPlot(wvf,'psf space',550);

% Old
% otfM = oiCalculateOTF(oi, wave, unit);  % Took changes from ISETBio.

nWave = numel(wavelist);

% All the PSFs
PSF = wvfGet(wvf,'psf');
if ~iscell(PSF)
    tmp = PSF; clear PSF; PSF{1} = tmp;
end

% Get the current data set.  It has the right size.  We over-write it
% below.
p = oiGet(oi,'photons');
oiHeight = size(p,1);
oiWidth = size(p,2);

% otf = zeros(oiSize,oiSize,nWave);

for ww = 1:nWave
    
    % Deal with non square scenes
    if oiWidth ~= oiHeight
        %  sz = round(double(abs(oiWidth - oiHeight)/2));

        % Find the difference between height and width, and set sz to
        % compensate.
        delta = abs(oiWidth - oiHeight);
        if isodd(delta) 
            sz(1) = floor(delta/2); sz(2) = sz(1) + 1;
        else
            sz(1) = delta/2; sz(2) = sz(1);
        end

        if oiWidth < oiHeight
            % Add zeros to the columns
            photons = padarray(p(:,:,ww),[0,sz(1)],0,'pre');
            photons = padarray(photons,[0,sz(2)],0,'post');
            % photons = padarray(p(:,:,ww),[0,sz],0,'both');
            % photons = ImageConvFrequencyDomain(photons,PSF{ww}, 2);
            photons = fftshift(ifft2(fft2(photons) .* fft2(PSF{ww})));
            p(:,:,ww) = photons(:,sz(1)+(1:oiWidth));
        else
            photons = padarray(p(:,:,ww),[sz(1),0],0,'pre');
            photons = padarray(photons,[sz(2),0],0,'post');
            % photons = padarray(p(:,:,ww),[sz,0],0,'both');
            % photons = ImageConvFrequencyDomain(photons,PSF{ww}, 2);
            photons = fftshift(ifft2(fft2(photons) .* fft2(PSF{ww})));
            p(:,:,ww) = photons(sz(1)+(1:oiHeight),:);
        end
    else
        % BW:  Debugging as per DHB.  This line breaks the padding.
        % It seems the convolution is not circular. Currently
        % debugging in v_ibioRDT_wvfPadPSF.m

        % tmp = conv2(p(:,:,ww),PSF{ww},'same');

        % The ImageConvFrequencyDomain method almost always worked.
        % But for the slanted bar scene, for some reason, it had a
        % roll off at the edge towards zero that should not have been
        % there.  We tried various tests to see why, but none worked.
        % The method has parameters in how it calls fft2() that nearly
        % always work but for some reason fail us in the slanted edge
        % case.  (See v_icam_wvfPadPSF).  So we now do this step in
        % the compute the same way that it is done in opticsOTF.

        % In this case, we need an fftshift that is not needed in the
        % opticsOTF case. Perhaps that is because we store the OTF in
        % a different format there and here we simply take fft2(PSF).
        % 
        % That may be the reason why there is a 1 pixel shift in the
        % result for odd (but not even) size images.  See
        % v_icam_wvfPadPSF.m.  Let's try to eliminate
        %
        % Deprecated because it pads and causes the roll off sometimes
        % p(:,:,ww) = ImageConvFrequencyDomain(p(:,:,ww), PSF{ww}, 2 );

        % Designed to match the opticsOTF values
        p(:,:,ww) = ifft2( fft2(p(:,:,ww)) .* fft2(ifftshift(PSF{ww})) );
        
    end
    % otf requires a single wavelength
    % otf(:,:,ww) = wvfGet(wvf,'otf',wavelist(ww));
end

oi = oiSet(oi,'photons',p);

wvfOptics = wvf2optics(wvf);

% Update the OTF struct while preserve the optics struct.
oi.optics.OTF = wvfOptics.OTF;

% We saved OTF in optics, we can clear the data saved in wvf, if we need
% them, we can call wvfCompute.
wvf = wvfClearData(wvf);

oi = oiSet(oi,'optics wvf',wvf);
end
