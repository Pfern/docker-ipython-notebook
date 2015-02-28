# IPython container used for Galaxy IPython Integration
#
# VERSION       0.3.0

FROM ubuntu:14.04

MAINTAINER Björn A. Grüning, bjoern.gruening@gmail.com

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update && apt-get install --no-install-recommends -y apt-transport-https \
    libzmq1 libzmq-dev python-dev libc-dev pandoc python-pip pkg-config \
    build-essential libblas-dev liblapack-dev gfortran \
    libfreetype6-dev libpng-dev net-tools procps \
    r-base libreadline-dev && \
    pip install distribute --upgrade && \
    pip install pyzmq ipython==3.0 jinja2 tornado pygments \
        numpy biopython scikit-learn pandas \
        scipy sklearn-pandas bioblend matplotlib patsy pysam khmer dendropy ggplot mpld3 sympy rpy2 && \
        ##bash_kernel && \
    # Install IRKernel, the IPython R kernel
    apt-get -qq --no-install-recommends -y libcurl4-openssl-dev && \
    Rscript -e 'chooseCRANmirror(ind=81);install.packages("devtools"); install.packages("RCurl")' && \
    Rscript -e 'library(devtools); install_github("armstrtw/rzmq"); install_github("takluyver/IRdisplay"); install_github("takluyver/IRkernel"); IRkernel::installspec()' && \
    # Cleanup
    apt-get remove -y --purge libzmq-dev python-dev libc-dev build-essential binutils gfortran libreadline-dev && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#RUN wget https://github.com/zmughal/p5-Devel-IPerl/archive/master.zip && \
#    unzip master.zip && cd p5-Devel-IPerl-master && \
#    curl -L https://cpanmin.us | perl - --installdeps . && \
#    rm -rf p5-Devel-IPerl-master

# list all available kernels: ipython kernelspec list

ADD ./startup.sh /startup.sh
RUN chmod +x /startup.sh

ADD ./monitor_traffic.sh /monitor_traffic.sh
RUN chmod +x /monitor_traffic.sh

# /import will be the universal mount-point for IPython
# The Galaxy instance can copy in data that needs to be present to the IPython webserver
RUN mkdir /import /ipython_setup

# Some libraries will tries to save same data to $HOME, so this needs to be writeable   
ENV HOME /ipython_setup

# Install MathJax locally because it has some problems with https as reported here: https://github.com/bgruening/galaxy-ipython/pull/8
RUN python -c 'from IPython.external import mathjax; mathjax.install_mathjax("2.5.0")'

# We can get away with just creating this single file and IPython will create the rest of the
# profile for us.
RUN mkdir -p /ipython_setup/.ipython/profile_default/startup/
RUN mkdir -p /ipython_setup/.ipython/profile_default/static/custom/

ADD ./ipython-profile.py /ipython_setup/.ipython/profile_default/startup/00-load.py
ADD ./ipython_notebook_config.py /ipython_setup/.ipython/profile_default/ipython_notebook_config.py
ADD ./custom.js /ipython_setup/.ipython/profile_default/static/custom/custom.js
ADD ./custom.css /ipython_setup/.ipython/profile_default/static/custom/custom.css
RUN chmod 777 -R /import/ /ipython_setup/

# Add python module to a special folder for modules we want to be able to load within IPython
RUN mkdir /py/
ADD ./galaxy.py /py/galaxy.py
ADD ./put /py/put
ADD ./get /py/get
# Make sure the system is aware that it can look for python code here
ENV PYTHONPATH /py/:$PYTHONPATH
ENV PATH /py/:$PATH
RUN chmod 777 -R /py/

# Drop privileges
USER nobody

VOLUME ["/import/"]
WORKDIR /import/

# IPython will run on port 6789, export this port to the host system
EXPOSE 6789

# Start IPython Notebook
CMD /startup.sh
