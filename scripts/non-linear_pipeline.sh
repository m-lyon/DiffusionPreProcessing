#!/usr/bin/env bash
###--------------------------------------------------------
ver="1.0.0"
usage()
{
  cat << EOF
USAGE: 
  	non-linear_pipeline.sh

	Version: $ver
	
	Non-Linear Diffusion Processing Pipeline

COMPULSORY:
	-dwi [DWI nifti image]  DWI image, no preprocessing done.

	-bvec [bvecs]   bvecs file corresponding to Corrected DWI image.

	-bval [bvals]   bvals file corresponding to Corrected DWI image.

	-index [index] Index file for eddy. Uses default index for MadMS protocol if omitted.

	-acqp [acq_params] Acquisition parameters for eddy. Uses default index for MadMS protocol if omitted.

	-t1_whole [T1 bias corrected image] T1 image, bias corrected, not skull-stripped.

	-o [output base]   directory to create Outputs_NL/ within.

OPTIONAL:
	-i [image_prefix]   string to be prepended to output files eg. "1001BC_m00_"

RUN OPTIONS:
	By default, all steps will be run unless specified below.

	-dwi_pre    Runs DWI pre-processing steps.

	-eddy       Runs eddy motion correction.

	-t1_pre     Runs T1 pre-processing steps.

	-nl_reg     Runs non-linear registration steps.
	
MISC:
	-h	Shows this message.

	-v	Displays version.

example:
	non-linear_pipeline.sh -dwi 1001BC_m12_dwi.nii.gz \\
    -bvec 1001BC_m12_dwi.bvec \\
    -bval 1001BC_m12_dwi.bval \\
    -index index.txt \\
    -acqp acq_params.txt \\
	-t1_whole 1001BC_m12_t1_c_acpc.nii.gz \\
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
        -t1_whole)
			shift
			if [[ $# > 0 ]];
			then
				if [ -f "${1}" ];
                then
                    t1_whole="${1}"
                else
                    echo "[ERROR]: Invalid file given for -t1_whole: ${1}"
				    exit 1
                fi
			else
				echo "[ERROR]: No input given for -t1_whole"
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
        -eddy)
            shift
            all_flag="N"
            eddy_flag="Y"
            ;;
        -t1_pre)
            shift
            all_flag="N"
            t1_pre_flag="Y"
            ;;
        -nl_reg)
            shift
            all_flag="N"
            nl_reg_flag="Y"
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
output_dir="$output_base/Outputs_NL"

# Processing paths
preprocess_dir="$output_dir/preprocessing"
brain_extract_dir="$preprocess_dir/brain_extraction"
dwi_pre_dir="$preprocess_dir/dwi_pre"
eddy_dir="$preprocess_dir/eddy"
t1_pre_dir="$preprocess_dir/t1_pre"
nl_reg_dir="$preprocess_dir/nl_registration"

# Non-Linear Specific Functions
runEddy(){

    # Inputs
    imain="$dwi_pre_dir/${pre}dwi_denoised_degibbs_bias.nii.gz"
    mask="$dwi_pre_dir/${pre}b0_avg_brain_mask.nii.gz"
    checkInputFiles "runEddy" $imain $mask $index $acqp $bvec $bval

    # Outputs
    [ ! -d $eddy_dir ] && mkdir $eddy_dir
    out="$eddy_dir/${pre}dwi_denoised_degibbs_bias_eddy"

    # Run
    printf "\n\nRunning Eddy\n\n"
    eddy_cuda9.1 --imain=$imain --mask=$mask --index=$index \
    --acqp=$acqp --bvecs=$bvec --bvals=$bval --out=$out --flm=quadratic \
    --verbose
    mrconvert -datatype int16 "${out}.nii.gz" "${out}.nii.gz"
}

getCorrectedB0(){

    # Inputs
    bvec="$eddy_dir/${pre}dwi_denoised_degibbs_bias_eddy.eddy_rotated_bvecs"
    in_dwi="$eddy_dir/${pre}dwi_denoised_degibbs_bias_eddy.nii.gz"
    checkInputFiles "getCorrectedB0" $in_dwi $bvec $bval

    # Outputs
    out_b0="$eddy_dir/${pre}eddy_b0_avg.nii.gz"
    out_b0_brain="$eddy_dir/${pre}eddy_b0_avg_brain.nii.gz"
    
    # Run
    printf "\n\nExtracting Eddy corrected B0 volumes\n\n"
    # Extract DWI volumes and create average
    dwiextract -fslgrad $bvec $bval -bzero $in_dwi - | \
    mrmath -datatype int16 -axis 3 - mean $out_b0
    # brain extract
    bet $out_b0 $out_b0_brain -m -f 0.2
}

inverseT1(){
    
    # Inputs
    t1_brain="$brain_extract_dir/${pre}BrainExtractionBrain.nii.gz"
    t1_mask="$brain_extract_dir/${pre}BrainExtractionMask.nii.gz"
    checkInputFiles "inverseT1" $t1_brain $t1_mask

    # Outputs
    [ ! -d $t1_pre_dir ] && mkdir $t1_pre_dir
    out_img="$t1_pre_dir/${pre}t1_c_brain_inv.nii.gz"

    # Run
    printf "\n\nInverting T1 Contrast\n\n"
    inv_range=$(mrstats -output max $t1_brain)
    fslmaths $t1_brain -mul -1 -add $inv_range -mas $t1_mask $out_img -odt short
}

rigidRegistration(){

    # Inputs
    t1_inv="$t1_pre_dir/${pre}t1_c_brain_inv.nii.gz"
    b0_in="$eddy_dir/${pre}eddy_b0_avg_brain.nii.gz"
    checkInputFiles "rigidRegistration" $t1_inv $b0_in

    # Outputs
    t1_inv_out="$t1_pre_dir/${pre}t1_c_brain_inv_dwispace.nii.gz"
    xfm="$t1_pre_dir/${pre}t1tob0_rigid.mat"

    # Run
    printf "\n\nRigidly Registering T1 to DWI space\n\n"
    flirt -in $t1_inv -out $t1_inv_out -ref $b0_in -omat $xfm -dof 6 -interp spline
}

nlRegistration(){
    # First rigidly align T1 to DWI space (so the bvecs will not need rotating)
    # Then apply SyN registration

    # Inputs
    t1_inv_dwispace="$t1_pre_dir/${pre}t1_c_brain_inv_dwispace.nii.gz"
    b0_in="$eddy_dir/${pre}eddy_b0_avg_brain.nii.gz"
    checkInputFiles "nlRegistration" $t1_inv_dwispace $b0_in

    # Outputs
    [ ! -d $nl_reg_dir ] && mkdir $nl_reg_dir
    output_prefix="$nl_reg_dir/${pre}eddy_b0_avg_brain_SyN_"

    # Run
    printf "\n\nCalculating warp from b0 -> T1\n\n"
    ANTS 3 -m CC[$t1_inv_dwispace,$b0_in,1,2] -i 100x50x30x10 \
    -o $output_prefix -t SyN[0.25] -r Gauss[3,0]
}

applyWarp(){

    # Inputs
    dwi_in="$eddy_dir/${pre}dwi_denoised_degibbs_bias_eddy.nii.gz"
    t1_ref="$t1_pre_dir/${pre}t1_c_brain_inv_dwispace.nii.gz"
    warp="$nl_reg_dir/${pre}eddy_b0_avg_brain_SyN_Warp.nii.gz"
    affine="$nl_reg_dir/${pre}eddy_b0_avg_brain_SyN_Affine.txt"
    checkInputFiles "applyWarp" $dwi_in $t1_ref $warp $affine

    # Outputs
    dwi_out="$nl_reg_dir/${pre}dwi_corrected.nii.gz"

    # Run
    printf "\n\nApplying warp to whole DWI 4D volume.\n\n"
    WarpTimeSeriesImageMultiTransform 4 $dwi_in $dwi_out -R $t1_ref $warp $affine
}

moveOutputs(){

    # Inputs
    in_dwi="$nl_reg_dir/${pre}dwi_corrected.nii.gz"
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
checkRuntimeInputs "$dwi" "DWI Image" "$bvec" "B-Vectors" "$bval" "B-Values" \
                   "$t1_whole" "T1 Image" "$acqp" "Eddy Acquisition Params" \
                   "$output_base" "Output Base" "$index" "Eddy Index"
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

## Eddy
if [[ $all_flag = "Y" ]] || [[ $eddy_flag = "Y" ]];
then
    [ -d $eddy_dir ] && rm -rf $eddy_dir
    runEddy
    getCorrectedB0
fi

## T1 Pre-processing
if [[ $all_flag = "Y" ]] || [[ $t1_pre_flag = "Y" ]];
then
    [ -d $t1_pre_dir ] && rm -rf $t1_pre_dir
    extractBrain
    inverseT1
    rigidRegistration
fi

## Non-Linear Registration
if [[ $all_flag = "Y" ]] || [[ $nl_reg_flag = "Y" ]];
then
    [ -d $nl_reg_dir ] && rm -rf $nl_reg_dir
    nlRegistration
    applyWarp
    moveOutputs
fi