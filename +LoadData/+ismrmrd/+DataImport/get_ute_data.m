function [data,traj] = get_ute_data(ute_file)
try
    parent_path = which('LoadData.ismrmrd.DataImport.get_ute_data');
    idcs = strfind(parent_path,filesep);%determine location of file separators
    parent_path = parent_path(1:idcs(end-1)-1);
catch 
    parent_path = cd;
end
twix = LoadData.ismrmrd.DataImport.mapVBVD(ute_file);
if length(twix) > 1
    twix = twix{end};
end
twix.flagIgnoreSeg = 1;
twix.image.flagIgnoreSeg = 1;
twix.image.flagAverageReps = 1;
twix.flagAverageReps = 1;

data = squeeze(double(twix.image()));

Seq_Name = twix.hdr.Config.SequenceFileName;

if contains(Seq_Name,'xe_radial_Dixon')
    data = data(:,:,:,end);
    data = permute(data,[1 3 2]);
    traj = LoadData.ismrmrd.DataImport.gas_exchange_traj_gen(size(data,1),size(data,2),twix);
elseif contains(Seq_Name,'SPIRAL')
    data = permute(data,[1 3 2]);
    traj = LoadData.ismrmrd.DataImport.seek_spiral_traj(twix);
else
    data = data(:,:,:,end);
    data = permute(data,[1 3 2]);
    traj = LoadData.ismrmrd.DataImport.gas_exchange_traj_gen(size(data,1),size(data,2),twix);
end
