#permet a docker dutiliser cette image pour exécuter le code python qui se touve dans docker hub
FROM python:3.12-slim 
#Pour définir un dossier /app à lintérieur du conteneur Docker, afin placer les fichiers de notre application et de travailler depuis ce dossier.
WORKDIR /app    
#copier le fichier requirements.txt depuis ton ordinateur vers le dossier /app à lintérieur de limage Docker contient les bibliothèques Python nécessaires à ton application
COPY requirements.txt .
#télécharger et installer toutes les bibliothèques Python nécessaires à ton application dans lenvironnement Python du conteneur Docker.
RUN pip install --no-cache-dir -r requirements.txt 

#copier le fichier app.py depuis ton ordinateur vers le dossier /app à lintérieur de limage Docker.

COPY app.py . 
#créer un nouvel utilisateur Linux appelé appuser à lintérieur de limage Docker.
RUN useradd -m appuser 
#dire à Docker dutiliser lutilisateur appuser pour exécuter les prochaines instructions du Dockerfile et, surtout, le processus principal du conteneur.
USER appuser 
#déclarer le port réseau utilisé par ton application à lintérieur du conteneur Docker.

EXPOSE 8080 
#définir la commande qui sera exécutée au démarrage du conteneur Docker pour lancer ton application Python Flask.
CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]
