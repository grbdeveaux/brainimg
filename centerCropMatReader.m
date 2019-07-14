function data = centerCropMatReader(filename,windowSize)
%
% Copyright 2018 The MathWorks, Inc.

inp = load(filename);
f = fields(inp);
temp=inp.(f{1});
sz = size(temp);
[R,C,P] = cropWindow(sz,windowSize);
data = temp(R,C,P,:);
end


function [rows, cols, planes] = cropWindow(sz, outputSize)
% Position crop window in center of feature map of size sz.
centerX = floor(sz(1:3)/2 + 1);
centerWindow = floor(outputSize/2 + 1);

offset = centerX - centerWindow + 1;

R = offset(1);
C = offset(2);
P = offset(3);

H = outputSize(1);
W = outputSize(2);
D = outputSize(3);

if outputSize(1) < sz(1)
    rows = R:(R + H - 1);
else
    rows = 1:sz(1);
end

if outputSize(2) < sz(2)
    cols   = C:(C + W - 1);
else
    cols = 1:sz(2);
end

if outputSize(3) < sz(3)
    planes = P:(P + D - 1);
else
    planes = 1:sz(3);
end

end