#!/usr/bin/env bash

# This shell script contains functions to be used in the v5 Pipeline

checkInputFiles(){
    # This function checks that files given to it exist, 
    # and exits with status "1"
    # and an error message if they do not

    # ${1} = descriptive name of function
    # ${n>1} = files to check they exist and are readable

    # example: checkInputFiles "dwidenoise" dwi.nii.gz dwi.bvec dwi.bval
    func_name="${1}"
    shift

    while [[ $# > 0 ]];
    do
        if [ -r "${1}" ];
        then
            shift
        else
            echo "[ERROR]: Cannot start ${func_name} as ${1} does not exist"
            exit 1
        fi
    done
}

checkRuntimeInputs(){
    while [[ $# > 0 ]];
    do
        if [ -z "${1}" ];
        then
            echo "[ERROR]: ${2} is required"
            exit 1
        fi
        shift
        shift
    done
    if [[ $CONDA_DEFAULT_ENV != "MADMS_v4"* ]];
    then
        echo $CONDA_DEFAULT_ENV
        echo "[ERROR]: MADMS_v4 conda environment not selected"
        exit 1
    fi
}

checkQualityControlDir(){
    # $qc_flag will be set to "-qc" if qc specified
    # $all_flag set to "Y" by default
    # $qc_output_dir is the subject directory within the study qc directory

    if [ -n "$qc_flag" ] || [[ $all_flag = "Y" ]];
    then
        [ -d "$output_dir/qc" ] &&  rm -r "$output_dir/qc"
        # if $qc_output_dir variable exists and is a directory, delete files within
        if [ -n "$qc_output_dir" ] && [ -d "$qc_output_dir" ];
        then
            find "$qc_output_dir" -type f -delete
        fi
    fi
}

makeProcessingDir(){
    if [ ! -d "$preprocess_dir" ];
    then
        printf "\n\nMaking Outputs directory\n\n"
        mkdir -p "$preprocess_dir"
    fi
}

denoise(){
    # Here we are denoising the DWI image.
    # We also import the gradient table for ease of use in dwibiascorrect,
    # as well as constraining to int16 datatype for space,
    # and constraining voxel size to 1,1,2 (to remove floating point error)

    # Inputs
    checkInputFiles "denoise" $dwi

    # Outputs
    [ ! -d $dwi_pre_dir ] && mkdir $dwi_pre_dir
    out_dwi="$dwi_pre_dir/${pre}dwi_denoised.mif"

    # Run
    printf "\n\nDenoising\n\n"
    dwidenoise $dwi - | mrconvert -fslgrad $bvec $bval \
    -datatype int16 -vox 1,1,2 - $out_dwi
}

degibbs(){
    # Here we are removing Gibbs ringing artefacts from the DWI,
    # whilst constraining to 16bit signed integer.
    
    # Inputs
    in_dwi="$dwi_pre_dir/${pre}dwi_denoised.mif"
    checkInputFiles "degibbs" $in_dwi

    # Outputs
    out_dwi="$dwi_pre_dir/${pre}dwi_denoised_degibbs.mif"

    # Run
    printf "\n\nDegibbsing\n\n"
    mrdegibbs -datatype int16 $in_dwi $out_dwi
}

biasCorrectDWI(){
    # Here we are correcting the DWI image for bias field inhomoegeneities,
    # using the ANTs N4 Algorithm
    # This step is used to improve DWI brain extraction.
    
    # Inputs
    in_dwi="$dwi_pre_dir/${pre}dwi_denoised_degibbs.mif"
    checkInputFiles "biasCorrectDWI" $in_dwi

    # Outputs
    out_dwi="$dwi_pre_dir/${pre}dwi_denoised_degibbs_bias.nii.gz"

    # Run
    printf "\n\nN4 Bias Correcting\n\n"
    dwibiascorrect $in_dwi $out_dwi -ants -tempdir $dwi_pre_dir
}

bZeroVolumes(){
    # Here we extract an average of the two B0 volumes,
    # whilst constraining to 16bit signed integer.

    # Inputs
    in_dwi="$dwi_pre_dir/${pre}dwi_denoised_degibbs_bias.nii.gz"
    checkInputFiles "bZeroVolumes" $in_dwi

    # Outputs
    out_b0="$dwi_pre_dir/${pre}b0_avg.nii.gz"

    # Run
    printf "\n\nCreating Average B0 Volume\n\n"
    dwiextract -fslgrad $bvec $bval -bzero $in_dwi - | \
    mrmath -datatype int16 -axis 3 - mean $out_b0
}

fslBet(){
    # Here we apply FSL's bet to obtain a brain mask
    # and a skull-stripped average b0
    
    # Inputs
    in_dwi="$dwi_pre_dir/${pre}b0_avg.nii.gz"
    checkInputFiles "fslBet" $in_dwi

    # Outputs
    out_img="$dwi_pre_dir/${pre}b0_avg_brain.nii.gz"

    # Run
    printf "\n\nBetting DWI\n\n"
    bet $in_dwi $out_img -m -f 0.2
}

extractBrain(){

    # Inputs
    t1_template="$resources_dir/t1_template.nii.gz"
    t1_prob_mask="$resources_dir/t1_template_probability_mask.nii.gz"
    t1_reg_mask="$resources_dir/t1_template_registration_mask.nii.gz"
    checkInputFiles "extractBrain" $t1_whole $t1_template $t1_prob_mask $t1_reg_mask

    # Outputs
    [ ! -d $brain_extract_dir ] && mkdir $brain_extract_dir

    # Run
    printf "\n\nExtracting brain from T1 image.\n\n"
    antsBrainExtraction.sh -d 3 -a $t1_whole -e $t1_template \
    -m $t1_prob_mask -f $t1_reg_mask \
    -o $brain_extract_dir/${pre} -k 1
}

runPostProcess(){

    # Inputs
    in_dwi="$preprocess_dir/${pre}dwi_corrected.nii.gz"
    in_bvec="$preprocess_dir/${pre}dwi_corrected.bvec"
    in_bval="$preprocess_dir/${pre}dwi_corrected.bval"
    t1_whole="$output_dir/${pre}t1_c_acpc_brain.nii.gz"
    t1_brain="$output_dir/${pre}t1_c_acpc_brain.nii.gz"
    checkInputFiles "runPostProcess" $in_dwi $in_bvec $in_bval $t1_whole $t1_brain

    # Required
    run_command="v5_postprocessing.sh -dwi $in_dwi \
    -bvec $in_bvec -bval $in_bval -t1_whole $t1_whole \
    -t1_brain $t1_brain -o $output_dir \
    $sienax_flag $dti_flag $matlab_flag $tractseg_flag $qc_flag"

    # Optionals
    if [ ! -z $qc_study_dir ];
    then
        run_command+=" -qc_dir $qc_study_dir"
    fi
    if [ ! -z ${pre} ];
    then
        run_command+=" -i ${pre}"
    fi

    # Run
    printf "\n\nStarting Post Processing Steps\n\n"
    $run_command
}

# Functions
copyT1s(){
    # Copies T1 images to convenient output directory

    # Inputs
    t1_brain="$brain_extract_dir/${pre}BrainExtractionBrain.nii.gz"
    checkInputFiles "copyT1s" $t1_brain $t1_whole

    # Outputs
    t1_whole_out="$output_dir/${pre}t1_c_acpc_whole.nii.gz"
    t1_brain_out="$output_dir/${pre}t1_c_acpc_brain.nii.gz"
    cp -f $t1_brain $t1_brain_out
    cp -f $t1_whole $t1_whole_out
}