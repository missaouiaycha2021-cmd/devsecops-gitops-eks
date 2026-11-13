import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)

# Les étapes du pipeline : (icône, nom, description, couleur)
# Pour en ajouter une, il suffit d'ajouter une ligne ici.
ETAPES = [
    ("🤖", "Jenkins", "Lance le pipeline à chaque push sur GitHub", "#e8590c"),
    ("🔍", "SonarQube", "Analyse la qualité du code", "#1c7ed6"),
    ("🛡️", "Snyk", "Cherche les dépendances vulnérables", "#7048e8"),
    ("🐳", "Docker", "Construit l'image de l'application", "#0c8599"),
    ("🔬", "Trivy", "Scanne l'image à la recherche de failles", "#d6336c"),
    ("📦", "Docker Hub", "Publie l'image avec un tag par build", "#1971c2"),
    ("🔄", "ArgoCD", "Déploie automatiquement depuis Git", "#f08c00"),
    ("☸️", "EKS", "Fait tourner l'application sur Kubernetes", "#2f9e44"),
    ("👁️", "Wazuh", "Surveille la sécurité du cluster en continu", "#c92a2a"),
]

# Le style de la page (CSS). Tout est compact pour tenir sur un seul écran.
STYLE = """
* { box-sizing: border-box; }
body { margin: 0; font-family: "Segoe UI", Arial, sans-serif; color: #1b2440;
       background: linear-gradient(160deg, #eef3ff 0%, #fff0f6 55%, #fff9e6 100%);
       min-height: 100vh; }
.page { max-width: 1260px; margin: 0 auto; padding: 42px 24px 26px; }

.titre { text-align: center; margin-bottom: 22px; }
.titre h1 { font-size: clamp(2.1rem, 4.8vw, 3.6rem); margin: 0 0 12px; line-height: 1.1; }
.titre p { font-size: 1.25rem; color: #4a5578; margin: 0 auto; max-width: 820px; }

.pod { display: flex; flex-wrap: wrap; justify-content: center; align-items: center;
       gap: 4px 14px; background: white; border-radius: 999px; padding: 15px 32px;
       width: fit-content; max-width: 100%; margin: 0 auto 28px;
       box-shadow: 0 4px 14px rgba(27, 36, 64, 0.08); font-size: 1.1rem;
       color: #4a5578; text-align: center; }
.pod strong { color: #2f9e44; font-size: 1.25rem; }

.grille { display: flex; flex-wrap: wrap; justify-content: center; gap: 20px; }
.carte { flex: 0 1 390px; background: white; border-radius: 16px; padding: 22px 24px;
         border-top: 6px solid var(--couleur);
         box-shadow: 0 4px 14px rgba(27, 36, 64, 0.08); }
.entete { display: flex; align-items: center; gap: 12px; }
.icone { font-size: 2.15rem; }
.carte h2 { margin: 0; font-size: 1.42rem; color: var(--couleur); flex: 1; }
.numero { font-weight: 700; font-size: 1.28rem; color: var(--couleur); }
.carte p { margin: 9px 0 0; color: #4a5578; font-size: 1.07rem; }

.pied { text-align: center; margin-top: 28px; color: #4a5578; font-size: 1rem; }
.pied a { color: #1c7ed6; }
"""


@app.route("/")
def accueil():
    # Nom du pod : Kubernetes le met dans la variable HOSTNAME.
    pod = os.environ.get("HOSTNAME") or socket.gethostname()

    # On construit une carte HTML pour chaque étape.
    cartes = ""
    for i, (icone, nom, description, couleur) in enumerate(ETAPES, start=1):
        cartes += (
            f'<div class="carte" style="--couleur: {couleur}">'
            f'<div class="entete"><span class="icone">{icone}</span>'
            f"<h2>{nom}</h2><span class=\"numero\">{i}</span></div>"
            f"<p>{description}</p></div>"
        )

    return f"""<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Flask App</title>
  <style>{STYLE}</style>
</head>
<body>
  <div class="page">
    <div class="titre">
      <h1>Du commit au cluster, automatiquement</h1>
      <p>Chaque push sur GitHub traverse {len(ETAPES)} étapes, de Jenkins
         jusqu'à la surveillance par Wazuh, sur Kubernetes (AWS EKS).</p>
    </div>
    <div class="pod">
      <span>Page servie par le pod</span>
      <strong>{pod}</strong>
      <span>(actualisez : avec 2 réplicas, le nom peut changer)</span>
    </div>
    <div class="grille">{cartes}</div>
    <div class="pied">Flask · Helm · Terraform · <a href="/health">/health</a></div>
  </div>
</body>
</html>"""


@app.route("/health")
def health():
    # Utilisé par Kubernetes pour savoir si l'application fonctionne.
    return jsonify(status="ok")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)