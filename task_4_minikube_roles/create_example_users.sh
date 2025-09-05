#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

# anton имеет право на:
# - просмотр ресурсов в sales-services-*
# - создание и обновление ресурсов в sales-services-test-*, создание, просмотр и редактирование с секретов в sales-services-test-*
bash $BASEDIR/create_user.sh anton namespace-viewer sales-developers

# bruno имеет право на всё то же, что и anton, но ещё и редактирование ресурсов в пространстве sales-services, включая создание подов и сервисов
bash $BASEDIR/create_user.sh bruno namespace-viewer sales-developers sales-devops

# caesar: lead-devops, имеет права на всё то же, что и просто девопс, но ещё и на просмотр секретов в своём пространстве
# Считаем, что в каждом домене таких по одному = )
bash $BASEDIR/create_user.sh caesar namespace-viewer sales-developers sales-devops sales-lead-devops

# dora: сотрудник ИБ, умеет читать всё во всех пространствах, кроме секретов
bash $BASEDIR/create_user.sh dora namespace-viewer security-group