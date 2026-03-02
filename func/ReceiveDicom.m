function [status, cmdout] = ReceiveDicom(path,port)
% path = 'DICOMFile';
% port = 11112;  % 建议不用 104

cmd = sprintf([ ...
    'storescp -v +xa -aet MYPC -od "%s" ', ...
    '--exec-on-reception "cmd /c taskkill /IM storescp.exe /F" %d' ...
], path, port);

[status, cmdout] = system(cmd);


end

