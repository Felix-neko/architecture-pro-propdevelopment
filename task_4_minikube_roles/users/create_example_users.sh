#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

# alice имеет право на:
# - просмотр ресурсов в sales-services-*
# - создание и обновление ресурсов в sales-services-test-*, создание, просмотр и редактирование с секретов в sales-services-test-*
bash $BASEDIR/create_user.sh alice namespace-viewer sales-developers

# bob имеет право на всё то же, что и alice, но ещё и редактирование ресурсов в sales-services
bash $BASEDIR/create_user.sh bob namespace-viewer sales-developers sales-devops

# charlie: lead-devops, имеет права на всё то же, что и просто девопс, но ещё и на просмотр секретов в своём пространстве
# Считаем, что в каждом домене таких по одному = )
bash $BASEDIR/create_user.sh charlie namespace-viewer sales-developers sales-devops sales-lead-devops