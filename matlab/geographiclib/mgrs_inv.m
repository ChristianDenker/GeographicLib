function [x, y, zone, northp, prec] = mgrs_inv(mgrs)
%MGRS_INV  Convert MGRS to UTM/UPS coordinates
%
%   [x, y, zone, northp] = MGRS_INV(mgrs)
%   [x, y, zone, northp, prec] = MGRS_INV(mgrs)
%
%   converts MGRS grid references to UTM/UPS coordinates.  mgrs is either a
%   2d character array of MGRS grid references (optionally padded on the
%   right with spaces) or a cell array of character strings.  x, y are the
%   easting and northing (in meters); zone is the UTM zone in [1,60] or 0
%   for UPS; northp is true (false) for the northern (southern) hemisphere.
%   prec is the precision of the grid reference.  The position of the
%   center of the grid square is returned.  To obtain the SW corner
%   subtract 0.5 * 10^(5-prec) from the easting and northing.  prec = -1
%   means that the grid reference consists of a grid zone only.  Illegal
%   MGRS references result in x = y = NaN, zone = -4, northp = false, prec
%   = -2.
%
%   See also MGRS_FWD.

% Copyright (c) Charles Karney (2015) <charles@karney.com>.
%
% This file was distributed with GeographicLib 1.42.

  if ischar(mgrs)
    mgrs = cellstr(mgrs);
  end
  if iscell(mgrs)
    s = size(mgrs);
    mgrs = char(deblank(mgrs));
  else
    error('mgrs must be cell array of strings or 2d char array')
  end
  mgrs = upper(mgrs);
  num = size(mgrs, 1);
  x = nan(num, 1); y = x; prec = -2 * ones(num, 1);
  northp = false(num, 1); zone = 2 * prec;
  if num == 0, return, end
  % pad with 5 spaces so we can access letter positions without checks
  mgrs = [mgrs, repmat(' ', num, 5)];
  d = isstrprop(mgrs(:,1), 'digit') & ~isstrprop(mgrs(:,2), 'digit');
  mgrs(d,2:end) = mgrs(d,1:end-1);
  mgrs(d,1) = '0';
  % check that spaces only at end
  contig = sum(abs(diff(isspace(mgrs), 1, 2)), 2) <= 1;
  utm = isstrprop(mgrs(:,1), 'digit') & contig;
  upss = (mgrs(:,1) == 'A' | mgrs(:,1) == 'B') & contig;
  upsn = (mgrs(:,1) == 'Y' | mgrs(:,1) == 'Z') & contig;
  [x(utm), y(utm), zone(utm), northp(utm), prec(utm)] = ...
      mgrs_inv_utm(mgrs(utm,:));
  [x(upss), y(upss), zone(upss), northp(upss), prec(upss)] = ...
      mgrs_inv_upss(mgrs(upss,:));
  [x(upsn), y(upsn), zone(upsn), northp(upsn), prec(upsn)] = ...
      mgrs_inv_upsn(mgrs(upsn,:));
  x = reshape(x, s); y = reshape(y, s); prec = reshape(prec, s);
  northp = reshape(northp, s); zone = reshape(zone, s);
end

function [x, y, zone, northp, prec] = mgrs_inv_utm(mgrs)
  zone = (mgrs(:,1) - '0') * 10 + (mgrs(:,2) - '0');
  ok = zone > 0 & zone <= 60;
  band = lookup('CDEFGHJKLMNPQRSTUVWX', mgrs(:,3));
  ok = ok & band >= 0;
  band = band - 10;
  northp = band >= 0;
  colind = lookup(['ABCDEFGH', 'JKLMNPQR', 'STUVWXYZ'], mgrs(:, 4)) - ...
           mod(zone - 1, 3) * 8;
  % good values in [0,8), bad values = -1
  colind(colind >= 8) = -1;
  rowind = lookup('ABCDEFGHJKLMNPQRSTUV', mgrs(:, 5));
  even = mod(zone, 2) == 0;
  bad = rowind < 0;
  rowind(even) = mod(rowind(even) - 5, 20);
  % good values in [0,20), bad values = -1
  rowind(bad) = -1;
  [x, y, prec] = decodexy(mgrs(:, 6:end));
  prec(mgrs(:,4) == ' ') = -1;
  ok = ok & (prec == -1 | (colind >= 0 & rowind >= 0));
  rowind = utmrow(band, colind, rowind);
  colind = colind + 1;
  x = colind * 1e5 + x;
  y = rowind * 1e5 + y;
  x(prec == -1) = ...
          (5 - (zone(prec == -1) == 31 & band(prec == -1) == 7)) * 1e5;
  y(prec == -1) = ...
          floor(8 * (band(prec == -1) + 0.5) * 100/90 + 0.5) * 1e5 + ...
          (1- northp(prec == -1)) * 100e5;
  x(~ok) = nan;
  y(~ok) = nan;
  northp(~ok) = false;
  zone(~ok) = -4;
  prec(~ok) = -2;
end

function [x, y, zone, northp, prec] = mgrs_inv_upss(mgrs)
  zone = zeros(size(mgrs,1),1);
  ok = zone == 0;
  northp = ~ok;
  eastp = lookup('AB', mgrs(:,1));
  ok = ok & eastp >= 0;
  colind = lookup(['JKLPQRSTUXYZ', 'ABCFGHJKLPQR'], mgrs(:, 2));
  ok = ok & (colind < 0 | mod(floor(colind / 12) + eastp, 2) == 0);
  rowind = lookup('ABCDEFGHJKLMNPQRSTUVWXYZ', mgrs(:, 3));
  [x, y, prec] = decodexy(mgrs(:, 4:end));
  prec(mgrs(:,2) == ' ') = -1;
  ok = ok & (prec == -1 | (colind >= 0 & rowind >= 0));
  x = (colind + 8) * 1e5 + x;
  y = (rowind + 8) * 1e5 + y;
  x(prec == -1) = ((2*eastp - 1) * floor(4 * 100/90 + 0.5) + 20) * 1e5;
  y(prec == -1) = 20e5;
  x(~ok) = nan;
  y(~ok) = nan;
  zone(~ok) = -4;
  prec(~ok) = -2;
end

function [x, y, zone, northp, prec] = mgrs_inv_upsn(mgrs)
  zone = zeros(size(mgrs,1),1);
  ok = zone == 0;
  northp = ok;
  eastp = lookup('YZ', mgrs(:,1));
  ok = ok & eastp >= 0;
  colind = lookup(['RSTUXYZ', 'ABCFGHJ'], mgrs(:, 2));
  ok = ok & (colind < 0 | mod(floor(colind / 7) + eastp, 2) == 0);
  rowind = lookup('ABCDEFGHJKLMNP', mgrs(:, 3));
  [x, y, prec] = decodexy(mgrs(:, 4:end));
  prec(mgrs(:,2) == ' ') = -1;
  ok = ok & (prec == -1 | (colind >= 0 & rowind >= 0));
  x = (colind + 13) * 1e5 + x;
  y = (rowind + 13) * 1e5 + y;
  x(prec == -1) = ((2*eastp - 1) * floor(4 * 100/90 + 0.5) + 20) * 1e5;
  y(prec == -1) = 20e5;
  x(~ok) = nan;
  y(~ok) = nan;
  northp(~ok) = false;
  zone(~ok) = -4;
  prec(~ok) = -2;
end

function [x, y, prec] = decodexy(xy)
  num = size(xy, 1);
  x = nan(num, 1); y = x;
  len = strlen(xy);
  prec = len / 2;
  digits = sum(isspace(xy) | isstrprop(xy, 'digit'), 2) == size(xy, 2);
  ok = len < 22 & mod(len, 2) == 0 & digits;
  prec(~ok) = -2;
  if ~any(ok), return, end
  x(prec == 0) = 0.5e5; y(prec == 0) = 0.5e5;
  minprec = max(1,min(prec(ok))); maxprec = max(prec(ok));
  for p = minprec:maxprec
    m = 1e5 / 10^p;
    x(prec == p) = str2double(cellstr(xy(prec == p, 0+(1:p)))) * m + m/2;
    y(prec == p) = str2double(cellstr(xy(prec == p, p+(1:p)))) * m + m/2;
  end
end

function irow = utmrow(iband, icol, irow)
% Input is MGRS (periodic) row index and output is true row index.  Band
% index is in [-10, 10) (as returned by LatitudeBand).  Column index
% origin is easting = 100km.  Returns 100  if irow and iband are
% incompatible.  Row index origin is equator.

% Estimate center row number for latitude band
% 90 deg = 100 tiles; 1 band = 8 deg = 100*8/90 tiles
  c = 100 * (8 * iband + 4)/90;
  northp = iband >= 0;
  minrow = cvmgt(floor(c - 4.3 - 0.1 * northp), -90, iband > -10);
  maxrow = cvmgt(floor(c + 4.4 - 0.1 * northp),  94, iband <   9);
  baserow = floor((minrow + maxrow) / 2) - 10;
  irow = mod(irow - baserow, 20) + baserow;
  fix = irow < minrow | irow > maxrow;
  if ~any(fix), return, end
  % Northing = 71*100km and 80*100km intersect band boundaries
  % The following deals with these special cases.
  % Fold [-10,-1] -> [9,0]
  sband = cvmgt(iband, -iband - 1, iband >= 0);
  % Fold [-90,-1] -> [89,0]
  srow = cvmgt(irow, -irow - 1, irow >= 0);
  % Fold [4,7] -> [3,0]
  scol = cvmgt(icol, -icol + 7, icol < 4);
  irow(fix & ~( (srow == 70 & sband == 8 & scol >= 2) | ...
                (srow == 71 & sband == 7 & scol <= 2) | ...
                (srow == 79 & sband == 9 & scol >= 1) | ...
                (srow == 80 & sband == 8 & scol <= 1) ) ) = 100;
end

function len = strlen(strings)
  num = size(strings, 1);
  len = repmat(size(strings, 2), num, 1);
  strings = strings(:);
  r = cumsum(ones(num,1));
  d = 1;
  while any(d)
    d = len > 0 & strings(num * (max(len, 1) - 1) + r) == ' ';
    len(d) = len(d) - 1;
  end
end

function ind = lookup(str, test)
% str is uppercase row string to look up in. test is col array to lookup
  q = str - 'A' + 1;
  t = zeros(27,1);
  t(q) = cumsum(ones(length(q),1));
  test = test - 'A' + 1;
  test(~(test >= 1 & test <= 26)) = 27;
  ind = t(test) - 1;
end