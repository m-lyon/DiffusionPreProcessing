#!/usr/bin/env bash
###--------------------------------------------------------
ver="1.0.0"
usage()
{
  cat << EOF
USAGE: 
  	topup_pipeline.sh

	Version: $ver
	
	Top-Up Diffusion Processing Pipeline

COMPULSORY:
	-dwi [DWI nifti image]  DWI image, no preprocessing done.

	-bvec [bvecs]   bvecs file corresponding to Corrected DWI image.

	-bval [bvals]   bvals file corresponding to Corrected DWI image.

	-blip_up [blip up dwi nifti]    DWI blip-up image.

	-blip_down [blip down dwi nifti]    DWI blip-down image.

	-index [index] Index file for eddy. Uses default index for MadMS protocol if omitted.

	-acqp [acq_params] Acquisition parameters for eddy. Uses default index for MadMS protocol if omitted.

	-o [output base]   Directory to create Outputs_TOPUP/ within.

OPTIONAL:
	-i [image_prefix]   String to be prepended to output files eg. "1001BC_m00_".

RUN OPTIONS:
	By default, all steps will be run unless specified below.

	-dwi_pre    Runs DWI pre-processing steps.

	-topup      Runs FSL Topup.

	-eddy       Runs eddy motion & phase correction.

MISC:
	-h	Shows this message.

	-v	Displays version.

example:
	topup_pipeline.sh -dwi 1001BC_m12_dwi.nii.gz \\
    -bvec 1001BC_m12_dwi.bvec \\
    -bval 1001BC_m12_dwi.bval \\
	-blip_down 1001BC_m12_bd.nii.gz \\
    -blip_up 1001BC_m12_bu.nii.gz \\
    -index index.txt \\
    -acqp acq_params.txt \\
	-o Analysis_v5/ -i 1001BC_m12_

EOF
}
all_flag="Y"
###--------------------------------------------------------
if [[ $# -eq 0 ]];
then
	usage
	exit 1
fi
OPTIND=1
while [[ $# > 0 ]]; do
    case "$1" in
        -dwi)
			shift
			if [[ $# > 0 ]];
			then
				if [ -f "${1}" ];
                then
                    dwi="${1}"
                else
                    echo "[ERROR]: Invalid file given for -dwi: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -dwi"
				exit 1
			fi
			shift
            ;;
        -bvec)
			shift
			if [[ $# > 0 ]];
			then
				if [ -r "${1}" ];
                then
                    bvec="${1}"
                else
                    echo "[ERROR]: Invalid file given for -bvec: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -bvec"
				exit 1
			fi
			shift
            ;;
        -bval)
			shift
			if [[ $# > 0 ]];
			then
				if [ -r "${1}" ];
                then
                    bval="${1}"
                else
                    echo "[ERROR]: Invalid file given for -bval: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -bval"
				exit 1
			fi
			shift
            ;;
        -index)
			shift
			if [[ $# > 0 ]];
			then
				if [ -r "${1}" ];
                then
                    index="${1}"
                else
                    echo "[ERROR]: Invalid file given for -index: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -index"
				exit 1
			fi
			shift
            ;;
        -acqp)
			shift
			if [[ $# > 0 ]];
			then
				if [ -r "${1}" ];
                then
                    acqp="${1}"
                else
                    echo "[ERROR]: Invalid file given for -acqp: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -acqp"
				exit 1
			fi
			shift
            ;;
        -blip_up)
			shift
			if [[ $# > 0 ]];
			then
				if [ -f "${1}" ];
                then
                    blip_up="${1}"
                else
                    echo "[ERROR]: Invalid file given for -blip_up: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -blip_up"
				exit 1
			fi
			shift
            ;;
        -blip_down)
			shift
			if [[ $# > 0 ]];
			then
				if [ -f "${1}" ];
                then
                    blip_down="${1}"
                else
                    echo "[ERROR]: Invalid file given for -blip_down: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -blip_down"
				exit 1
			fi
			shift
            ;;
        -o|--output_base)
			shift
		    if [[ $# > 0 ]];
			then
				if [ -d "${1}" ];
                then
                    output_base="$(realpath ${1})"
                else
                    echo "[ERROR]: Invalid directory given for -o: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -o"
				exit 1
			fi
			shift
            ;;
        -i|--input_prefix)
			shift
			if [[ $# > 0 ]];
			then
				pre="${1}"
			else
				echo "[ERROR]: No prefix given for -i"
				exit 1
			fi
			shift
            ;;
        -dwi_pre)
            shift
            all_flag="N"
            dwi_pre_flag="Y"
            ;;
        -topup)
            shift
            all_flag="N"
            topup_flag="Y"
            ;;
        -eddy)
            shift
            all_flag="N"
            eddy_flag="Y"
            ;;
        -h|--help)
            usage
            exit
            ;;
		-v|--version)
            echo "Version is: $ver"
            exit
            ;;
        *)
            usage
            exit
            ;;
    esac
done
###--------------------------------------------------------
# General functions are found within script below
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source $SCRIPTPATH/resources/functions.sh
output_dir="$output_base/Outputs_TOPUP"

# Processing paths
preprocess_dir="$output_dir/preprocessing"
brain_extract_dir="$preprocess_dir/brain_extraction"
dwi_pre_dir="$preprocess_dir/dwi_pre"
topup_dir="$preprocess_dir/topup"
eddy_dir="$preprocess_dir/eddy"

# TopUp Specific Functions
resampleBlips(){
    
    [ ! -d $topup_dir ] && mkdir $topup_dir
    # The blip-down has slightly different voxel sizes/orientation to full dwi volume
    # So we linearly register blip-down to 1st dwi volume, use that as blip-up/down pair

    # Inputs
    checkInputFiles "resampleBlips" $dwi $blip_down $blip_up

    # Outputs
    b0="$topup_dir/${pre}b0.nii.gz"
    blip_up_resampled="$topup_dir/${pre}bu_resampled.nii.gz"
    blip_down_resampled="$topup_dir/${pre}bd_resampled.nii.gz"
    xfm_up="$topup_dir/${pre}blipup2dwi.xfm"
    xfm_down="$topup_dir/${pre}blipdown2dwi.xfm"


    # Run
    printf "\n\nResampling Blip Down\n\n"
    mrconvert -coord 3 0 $dwi $b0
    flirt -in $blip_down -out $blip_down_resampled -ref $b0 -omat $xfm_down -dof 6 -interp spline
    flirt -in $blip_up -out $blip_up_resampled -ref $b0 -omat $xfm_up -dof 6 -interp spline
}

combineBlips(){
    # Here we also ensure the voxel size to be exactly 1,1,2.
    # Problems with eddy if the floating point values of dwi.nii
    # and the both_blips don't match
    
    # Inputs
    blip_up="$topup_dir/${pre}bu_resampled.nii.gz"
    blip_down="$topup_dir/${pre}bd_resampled.nii.gz"
    checkInputFiles "combineBlips" $blip_up $blip_down

    # Outputs
    both="$topup_dir/${pre}both_blips.nii.gz"

    # Run
    printf "\n\nCombining Blips\n\n"
    mrcat $blip_up $blip_down - | mrconvert -vox 1,1,2 - $both
}

fslTopup(){
    
    # Inputs
    both_blips="$topup_dir/${pre}both_blips.nii.gz"
    checkInputFiles "fslTopup" $both_blips

    # Outputs
    out_name="$topup_dir/${pre}topup"
    field="$topup_dir/${pre}topup_field"
    img_out="$topup_dir/${pre}topup_img"
    
    # Run
    printf "\n\nRunning Topup\n\n"
    topup --imain=$both_blips --datain=$acqp --config=b02b0.cnf \
    --out=$out_name --fout=$field --iout=$img_out --verbose
}

runEddy(){
    # Take note that this produces rotated bvecs
   
    # Inputs
    imain="$dwi_pre_dir/${pre}dwi_denoised_degibbs_bias.nii.gz"
    mask="$dwi_pre_dir/${pre}b0_avg_brain_mask.nii.gz"
    topup="$topup_dir/${pre}topup"
    checkInputFiles "runEddy" $imain $mask "${topup}_movpar.txt" \
                    "${topup}_fieldcoef.nii.gz" $index $acqp $bvec $bval

    # Outputs
    [ ! -d $eddy_dir ] && mkdir $eddy_dir
    out="$eddy_dir/${pre}dwi_denoised_degibbs_bias_eddy"

    # Run
    printf "\n\nRunning Eddy\n\n"
    eddy_cuda9.1 --imain=$imain --mask=$mask --index=$index \
    --acqp=$acqp --bvecs=$bvec --bvals=$bval --out=$out \
    --topup=$topup --flm=quadratic --verbose
}

moveOutputs(){

    # Inputs
    in_dwi="$eddy_dir/${pre}dwi_denoised_degibbs_bias_eddy.nii.gz"
    in_bvec="$eddy_dir/${pre}dwi_denoised_degibbs_bias_eddy.eddy_rotated_bvecs"
    in_bval="$bval"
    checkInputFiles "moveOutputs" $in_dwi $in_bvec $in_bval

    # Outputs
    out_dwi="$preprocess_dir/${pre}dwi_corrected.nii.gz"
    out_bvec="$preprocess_dir/${pre}dwi_corrected.bvec"
    out_bval="$preprocess_dir/${pre}dwi_corrected.bval"

    # Run
    printf "\n\nMoving Outputs\n\n"
    mrconvert -datatype int16 $in_dwi $out_dwi -force
    cp -f $in_bvec $out_bvec
    cp -f $in_bval $out_bval
}

### RUN
checkRuntimeInputs "$dwi" "DWI Image" "$blip_down" "Blip-down Image" \
                   "$blip_up" "Blip-up Image" "$bvec" "B-Vectors" \
                   "$acqp" "Eddy Acquisition Params" "$bval" "B-Values" \
                   "$index" "Eddy Index" "$output_base" "Output Base"
makeProcessingDir

## DWI Pre-processing
if [[ $all_flag = "Y" ]] || [[ $dwi_pre_flag = "Y" ]];
then
    [ -d $dwi_pre_dir ] && rm -rf $dwi_pre_dir
    denoise
    degibbs
    biasCorrectDWI
    bZeroVolumes
    fslBet
fi

## Topup
if [[ $all_flag = "Y" ]] || [[ $topup_flag = "Y" ]];
then
    [ -d $topup_dir ] && rm -rf $topup_dir
    resampleBlips
    combineBlips
    fslTopup
fi

## Eddy
if [[ $all_flag = "Y" ]] || [[ $eddy_flag = "Y" ]];
then
    [ -d $eddy_dir ] && rm -rf $eddy_dir
    runEddy
fi
