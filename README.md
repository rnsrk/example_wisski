# Example WissKI base Image 
The base image contains all necessary dependencies, modules, themes, config files, example semantics, and libraries to install WissKI for a working WissKI instance.

## Stack
* PHP:8.0
* Drupal:9.3.6
* WissKI:3.x-dev
* IIPServer:1.2
* Mirador:3
* Mariadb:10.5.12
* Blazegraph:2.1.5
* Solr: 8.11.1.

## Build
'''bash
docker build -t <image-name:tag> .
'''
## Run
'''bash
docker run --name <container-name> -p 80:80 -p 3306 -p 9999:9999 -p 8983:8983 <image-name:tag>
'''

## Preconfigured example WissKI in image rnsrk/wisski_example, i.e. with
'''bash
docker run --name wisskiExample -p 80:80 -p 3306:3306 -p 9999:9999 -p 8983:8983 rnsrk/wisski_example
'''

If you facing trouble with the ports, you may want to use 3000 and above for testing, like 

'''bash
docker run --name wisskiExample -p 3000:80 -p 3001:3306 -p 3002:9999 -p 3003:8983 rnsrk/wisski_example
'''

## Usage
Open your browser at `localhost` (respectively `localhost:3000` or the port you choosed for your apache).

## Ports inside docker
For performance and security reasons, you may do not want to expose databases etc. To connect to services inside docker networt, use 0.0.0.0 as network adress, i.e. 0.0.0.0:3306 would be the MariaDB inside the docker container.