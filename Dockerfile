
FROM snacdev/fsl:1.0

RUN apt-get update -y

# Install dcm2niix
#RUN apt-get install -y software-properties-common
#RUN apt-get update -y
#RUN add-apt-repository universe
RUN apt-get install -y dcm2niix
# Install MRtrix3 dependencies
# RUN apt-get install git g++ python python-numpy libeigen3-dev zlib1g-dev libqt4-opengl-dev libgl1-mesa-dev libfftw3-dev libtiff5-dev
RUN apt-get install -y git g++ python python-numpy libeigen3-dev zlib1g-dev libfftw3-dev libtiff5-dev
# Build MRtrix3
WORKDIR /code
RUN git clone https://github.com/MRtrix3/mrtrix3.git
WORKDIR mrtrix3
RUN ./configure -nogui
RUN ./build
RUN ./set_path
