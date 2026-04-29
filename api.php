<?php
// Votre clé secrète (doit être la même que ADMIN_TOKEN dans Flutter)
$admin_token_attendu = "JHKU33F6HIOV7XWK.'GD,()0()@78FOKNHY€TV&72-(+)";

// Récupérer le token envoyé par l'application
$headers = getallheaders();
$token_recu = $headers['Authorization'] ?? '';

if ($token_recu !== $admin_token_attendu) {
    header('HTTP/1.1 401 Unauthorized');
    echo json_encode(["erreur" => "Token invalide"]);
    exit;
}

// Si le token est bon, on envoie les données de recharge
$historique = [
    ["id" => 1, "utilisateur" => "Jean", "montant" => "50€", "type de carte" => "Paysafecard", "code de la carte cadeau" => "8800-3679-0963-8986", "date" => "2026-04-28"],
    ["id" => 2, "utilisateur" => "Marie", "montant" => "20€", "type de carte" => "Paysafecard", "code de la carte cadeau" => "8000-3009-1000-8986", "date" => "2026-04-29"]
];

echo json_encode($historique);
?>
