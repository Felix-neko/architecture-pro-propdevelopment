#!/usr/bin/env python3
"""
Kubernetes Permission Testing Script

Тестирует различные операции Kubernetes для проверки прав доступа пользователей.
Выводит результаты в виде таблицы с цветными индикаторами успеха/неудачи.
"""

import argparse
import sys
import os
import time
from typing import List, Dict, Tuple
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import base64

# ANSI color codes for terminal output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_header(text: str):
    """Печатает заголовок с выделением"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(60)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")

def success_mark():
    """Возвращает зеленую галочку"""
    return f"{Colors.GREEN}✓{Colors.END}"

def error_mark():
    """Возвращает красный крестик"""
    return f"{Colors.RED}✗{Colors.END}"

def load_kubeconfig(kubeconfig_path: str = None):
    """Загружает kubeconfig файл"""
    try:
        if kubeconfig_path:
            if not os.path.exists(kubeconfig_path):
                print(f"{error_mark()} Kubeconfig файл не найден: {kubeconfig_path}")
                return False
            config.load_kube_config(config_file=kubeconfig_path)
            print(f"{success_mark()} Загружен kubeconfig: {kubeconfig_path}")
        else:
            config.load_kube_config()
            print(f"{success_mark()} Загружен kubeconfig по умолчанию")
        return True
    except Exception as e:
        print(f"{error_mark()} Ошибка загрузки kubeconfig: {e}")
        return False

def get_target_namespaces(v1_core: client.CoreV1Api) -> List[str]:
    """Получает список целевых namespace (sales-services-* и owner-services-*)"""
    try:
        namespaces = v1_core.list_namespace()
        target_namespaces = []
        
        for ns in namespaces.items:
            ns_name = ns.metadata.name
            if ns_name.startswith('sales-services-') or ns_name.startswith('owner-services-'):
                target_namespaces.append(ns_name)
        
        target_namespaces.sort()
        return target_namespaces
    except ApiException as e:
        print(f"{error_mark()} Ошибка получения списка namespace: {e}")
        return []

def test_namespace_access(v1_core: client.CoreV1Api) -> Tuple[bool, List[str]]:
    """Тестирует доступ к чтению списка namespace"""
    print_header("ТЕСТ: Чтение списка namespace")
    
    try:
        namespaces = v1_core.list_namespace()
        ns_names = [ns.metadata.name for ns in namespaces.items]
        print(f"{success_mark()} Успешно получен список namespace ({len(ns_names)} шт.)")
        
        # Показываем только целевые namespace
        target_ns = [ns for ns in ns_names if ns.startswith('sales-services-') or ns.startswith('owner-services-')]
        if target_ns:
            print(f"   Найдены целевые namespace: {', '.join(target_ns)}")
        else:
            print(f"{Colors.YELLOW}   Целевые namespace (sales-services-*, owner-services-*) не найдены{Colors.END}")
        
        return True, target_ns
    except ApiException as e:
        print(f"{error_mark()} Ошибка доступа к namespace: {e}")
        return False, []

def test_configmap_operations(v1_core: client.CoreV1Api, namespaces: List[str]) -> Dict[str, Dict[str, bool]]:
    """Тестирует операции с ConfigMap"""
    print_header("ТЕСТ: Операции с ConfigMap")
    
    results = {}
    
    for namespace in namespaces:
        results[namespace] = {
            'create_configmap': False,
            'read_configmap': False
        }
        
        # Тест создания ConfigMap
        try:
            configmap = client.V1ConfigMap(
                metadata=client.V1ObjectMeta(name="test-config"),
                data={
                    "app.properties": "debug=true\nlog_level=info",
                    "database.url": "localhost:5432"
                }
            )
            
            # Попытка создать или обновить
            try:
                v1_core.create_namespaced_config_map(namespace=namespace, body=configmap)
                print(f"{success_mark()} {namespace}: ConfigMap создан")
            except ApiException as e:
                if e.status == 409:  # Already exists
                    v1_core.replace_namespaced_config_map(name="test-config", namespace=namespace, body=configmap)
                    print(f"{success_mark()} {namespace}: ConfigMap обновлен")
                else:
                    raise e
            
            results[namespace]['create_configmap'] = True
            
        except ApiException as e:
            print(f"{error_mark()} {namespace}: Ошибка создания ConfigMap - {e.reason}")
        
        # Тест чтения ConfigMap
        try:
            configmaps = v1_core.list_namespaced_config_map(namespace=namespace)
            print(f"{success_mark()} {namespace}: Список ConfigMap получен ({len(configmaps.items)} шт.)")
            results[namespace]['read_configmap'] = True
        except ApiException as e:
            print(f"{error_mark()} {namespace}: Ошибка чтения ConfigMap - {e.reason}")
    
    return results

def test_secret_operations(v1_core: client.CoreV1Api, namespaces: List[str]) -> Dict[str, Dict[str, bool]]:
    """Тестирует операции с Secret"""
    print_header("ТЕСТ: Операции с Secret")
    
    results = {}
    
    for namespace in namespaces:
        results[namespace] = {
            'create_secret': False,
            'list_secrets': False,
            'read_secret_data': False
        }
        
        # Тест создания Secret
        try:
            secret_data = {
                'foo': base64.b64encode(b'bar').decode('utf-8'),
                'username': base64.b64encode(b'admin').decode('utf-8'),
                'password': base64.b64encode(b'secret123').decode('utf-8')
            }
            
            secret = client.V1Secret(
                metadata=client.V1ObjectMeta(name="test-secret"),
                data=secret_data,
                type="Opaque"
            )
            
            # Попытка создать или обновить
            try:
                v1_core.create_namespaced_secret(namespace=namespace, body=secret)
                print(f"{success_mark()} {namespace}: Secret создан")
            except ApiException as e:
                if e.status == 409:  # Already exists
                    v1_core.replace_namespaced_secret(name="test-secret", namespace=namespace, body=secret)
                    print(f"{success_mark()} {namespace}: Secret обновлен")
                else:
                    raise e
            
            results[namespace]['create_secret'] = True
            
        except ApiException as e:
            print(f"{error_mark()} {namespace}: Ошибка создания Secret - {e.reason}")
        
        # Тест получения списка Secret
        try:
            secrets = v1_core.list_namespaced_secret(namespace=namespace)
            print(f"{success_mark()} {namespace}: Список Secret получен ({len(secrets.items)} шт.)")
            results[namespace]['list_secrets'] = True
        except ApiException as e:
            print(f"{error_mark()} {namespace}: Ошибка получения списка Secret - {e.reason}")
        
        # Тест чтения данных Secret
        try:
            secret = v1_core.read_namespaced_secret(name="test-secret", namespace=namespace)
            if secret.data and 'foo' in secret.data:
                decoded_value = base64.b64decode(secret.data['foo']).decode('utf-8')
                print(f"{success_mark()} {namespace}: Данные Secret прочитаны (foo='{decoded_value}')")
                results[namespace]['read_secret_data'] = True
            else:
                print(f"{error_mark()} {namespace}: Ключ 'foo' не найден в Secret")
        except ApiException as e:
            print(f"{error_mark()} {namespace}: Ошибка чтения данных Secret - {e.reason}")
    
    return results

def wait_for_pod_ready(v1_core: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 60) -> bool:
    """Ждет готовности Pod"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            pod = v1_core.read_namespaced_pod(name=pod_name, namespace=namespace)
            if pod.status.phase == "Running":
                # Проверяем, что контейнеры готовы
                if pod.status.container_statuses:
                    all_ready = all(container.ready for container in pod.status.container_statuses)
                    if all_ready:
                        return True
            elif pod.status.phase in ["Failed", "Succeeded"]:
                return True  # Pod завершился, логи должны быть доступны
        except ApiException:
            pass
        time.sleep(2)
    return False

def test_pod_operations(v1_core: client.CoreV1Api, namespaces: List[str]) -> Dict[str, Dict[str, bool]]:
    """Тестирует операции с Pod"""
    print_header("ТЕСТ: Операции с Pod")
    
    results = {}
    
    for namespace in namespaces:
        results[namespace] = {
            'list_pods': False,
            'create_pod': False,
            'read_pod_logs': False
        }
        
        # Тест получения списка Pod
        try:
            pods = v1_core.list_namespaced_pod(namespace=namespace)
            print(f"{success_mark()} {namespace}: Список Pod получен ({len(pods.items)} шт.)")
            results[namespace]['list_pods'] = True
        except ApiException as e:
            print(f"{error_mark()} {namespace}: Ошибка получения списка Pod - {e.reason}")
        
        # Тест создания Pod
        try:
            pod = client.V1Pod(
                metadata=client.V1ObjectMeta(name="hello-pod"),
                spec=client.V1PodSpec(
                    containers=[
                        client.V1Container(
                            name="nginx",
                            image="nginx:alpine",
                            ports=[client.V1ContainerPort(container_port=80)],
                            env=[
                                client.V1EnvVar(name="MESSAGE", value="It works!")
                            ]
                        )
                    ],
                    restart_policy="Always"
                )
            )
            
            # Попытка создать или обновить
            try:
                v1_core.create_namespaced_pod(namespace=namespace, body=pod)
                print(f"{success_mark()} {namespace}: Pod создан")
            except ApiException as e:
                if e.status == 409:  # Already exists
                    v1_core.delete_namespaced_pod(name="hello-pod", namespace=namespace)
                    print(f"   {namespace}: Ожидание удаления старого Pod...")
                    time.sleep(5)  # Ждем удаления
                    v1_core.create_namespaced_pod(namespace=namespace, body=pod)
                    print(f"{success_mark()} {namespace}: Pod пересоздан")
                else:
                    raise e
            
            results[namespace]['create_pod'] = True
            
            # Ждем готовности Pod
            print(f"   {namespace}: Ожидание готовности Pod...")
            if wait_for_pod_ready(v1_core, namespace, "hello-pod", timeout=30):
                print(f"   {namespace}: Pod готов")
            else:
                print(f"   {namespace}: Pod не готов, но попробуем получить логи")
            
        except ApiException as e:
            print(f"{error_mark()} {namespace}: Ошибка создания Pod - {e.reason}")
        
        # Тест чтения логов Pod - проверяем независимо от создания
        # Сначала пытаемся найти существующие поды
        existing_pods = []
        if results[namespace]['list_pods']:
            try:
                pods = v1_core.list_namespaced_pod(namespace=namespace)
                existing_pods = [pod.metadata.name for pod in pods.items if pod.status.phase in ["Running", "Succeeded", "Failed"]]
            except ApiException:
                pass
        
        # Если мы создали pod, добавляем его в список для проверки
        if results[namespace]['create_pod']:
            existing_pods.append("hello-pod")
        
        # Пытаемся прочитать логи из любого доступного пода
        log_read_success = False
        for pod_name in existing_pods:
            try:
                # Проверяем статус Pod перед чтением логов
                pod_status = v1_core.read_namespaced_pod(name=pod_name, namespace=namespace)
                print(f"   {namespace}: Проверяем логи Pod '{pod_name}' (статус: {pod_status.status.phase})")
                
                # Пытаемся получить логи с дополнительными параметрами
                logs = v1_core.read_namespaced_pod_log(
                    name=pod_name, 
                    namespace=namespace, 
                    tail_lines=10,
                    previous=False,
                    timestamps=False
                )
                if logs:
                    log_lines = logs.strip().split('\n')
                    print(f"{success_mark()} {namespace}: Логи Pod '{pod_name}' получены ({len(log_lines)} строк)")
                else:
                    print(f"{success_mark()} {namespace}: Логи Pod '{pod_name}' получены (пустые)")
                log_read_success = True
                break  # Успешно прочитали логи, выходим из цикла
                
            except ApiException as e:
                # Если основные логи недоступны, попробуем получить логи предыдущего контейнера
                if e.status == 400:  # Bad Request
                    try:
                        logs = v1_core.read_namespaced_pod_log(
                            name=pod_name, 
                            namespace=namespace, 
                            previous=True
                        )
                        print(f"{success_mark()} {namespace}: Логи предыдущего контейнера '{pod_name}' получены")
                        log_read_success = True
                        break
                    except ApiException:
                        print(f"   {namespace}: Логи Pod '{pod_name}' недоступны - контейнер еще не запустился")
                        continue  # Пробуем следующий pod
                elif e.status == 403:  # Forbidden
                    print(f"{error_mark()} {namespace}: Ошибка чтения логов Pod '{pod_name}' - {e.reason}")
                    break  # Нет прав, не пробуем другие поды
                else:
                    print(f"   {namespace}: Ошибка чтения логов Pod '{pod_name}' - {e.reason}")
                    continue  # Пробуем следующий pod
        
        # Если не удалось прочитать логи ни одного пода, но есть права на список подов
        if not log_read_success and not existing_pods and results[namespace]['list_pods']:
            print(f"{error_mark()} {namespace}: Нет подов для чтения логов")
        elif not log_read_success and existing_pods:
            print(f"{error_mark()} {namespace}: Не удалось прочитать логи ни одного пода")
        
        results[namespace]['read_pod_logs'] = log_read_success
    
    return results

def format_cell(content: str, width: int) -> str:
    """Форматирует ячейку таблицы с учетом ANSI кодов"""
    # Для символов ✓ и ✗ с цветными кодами используем фиксированное выравнивание
    if '✓' in content or '✗' in content:
        # Добавляем пробелы после символа для выравнивания
        return content + ' ' * (width - 1)
    else:
        return f"{content:<{width}}"

def print_results_table(namespaces: List[str], configmap_results: Dict, secret_results: Dict, pod_results: Dict):
    """Выводит итоговую таблицу результатов"""
    print_header("ИТОГОВАЯ ТАБЛИЦА РЕЗУЛЬТАТОВ")
    
    # Определяем ширину колонок
    col_width = 12  # Фиксированная ширина для лучшего выравнивания
    ns_width = 20
    
    # Заголовки колонок
    headers = ["CM Create", "CM Read", "Sec Create", "Sec List", "Sec Read", "Pod List", "Pod Create", "Pod Logs"]
    
    # Заголовок таблицы
    header_parts = [f"{'Namespace':<{ns_width}}"]
    for h in headers:
        header_parts.append(f"{h:<{col_width}}")
    header = " | ".join(header_parts)
    print(header)
    print("-" * len(header))
    
    # Строки данных
    for namespace in namespaces:
        cm_create = "✓" if configmap_results.get(namespace, {}).get('create_configmap', False) else "✗"
        cm_read = "✓" if configmap_results.get(namespace, {}).get('read_configmap', False) else "✗"
        sec_create = "✓" if secret_results.get(namespace, {}).get('create_secret', False) else "✗"
        sec_list = "✓" if secret_results.get(namespace, {}).get('list_secrets', False) else "✗"
        sec_read = "✓" if secret_results.get(namespace, {}).get('read_secret_data', False) else "✗"
        pod_list = "✓" if pod_results.get(namespace, {}).get('list_pods', False) else "✗"
        pod_create = "✓" if pod_results.get(namespace, {}).get('create_pod', False) else "✗"
        pod_logs = "✓" if pod_results.get(namespace, {}).get('read_pod_logs', False) else "✗"
        
        # Применяем цвета только при выводе
        cm_create_colored = f"{Colors.GREEN}{cm_create}{Colors.END}" if cm_create == "✓" else f"{Colors.RED}{cm_create}{Colors.END}"
        cm_read_colored = f"{Colors.GREEN}{cm_read}{Colors.END}" if cm_read == "✓" else f"{Colors.RED}{cm_read}{Colors.END}"
        sec_create_colored = f"{Colors.GREEN}{sec_create}{Colors.END}" if sec_create == "✓" else f"{Colors.RED}{sec_create}{Colors.END}"
        sec_list_colored = f"{Colors.GREEN}{sec_list}{Colors.END}" if sec_list == "✓" else f"{Colors.RED}{sec_list}{Colors.END}"
        sec_read_colored = f"{Colors.GREEN}{sec_read}{Colors.END}" if sec_read == "✓" else f"{Colors.RED}{sec_read}{Colors.END}"
        pod_list_colored = f"{Colors.GREEN}{pod_list}{Colors.END}" if pod_list == "✓" else f"{Colors.RED}{pod_list}{Colors.END}"
        pod_create_colored = f"{Colors.GREEN}{pod_create}{Colors.END}" if pod_create == "✓" else f"{Colors.RED}{pod_create}{Colors.END}"
        pod_logs_colored = f"{Colors.GREEN}{pod_logs}{Colors.END}" if pod_logs == "✓" else f"{Colors.RED}{pod_logs}{Colors.END}"
        
        # Форматируем строку с правильным выравниванием
        row_parts = [f"{namespace:<{ns_width}}"]
        row_parts.extend([
            format_cell(cm_create_colored, col_width),
            format_cell(cm_read_colored, col_width),
            format_cell(sec_create_colored, col_width),
            format_cell(sec_list_colored, col_width),
            format_cell(sec_read_colored, col_width),
            format_cell(pod_list_colored, col_width),
            format_cell(pod_create_colored, col_width),
            format_cell(pod_logs_colored, col_width)
        ])
        row = " | ".join(row_parts)
        print(row)

def main():
    """Основная функция"""
    parser = argparse.ArgumentParser(
        description="Тестирование прав доступа Kubernetes пользователей",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры использования:
  python3 test_permissions.py                           # Использовать kubeconfig по умолчанию
  python3 test_permissions.py --kubeconfig kubeconfig_alice  # Использовать конкретный kubeconfig
        """
    )
    
    parser.add_argument(
        '--kubeconfig',
        type=str,
        help='Путь к kubeconfig файлу (по умолчанию используется ~/.kube/config)'
    )
    
    args = parser.parse_args()
    
    print_header("KUBERNETES PERMISSION TESTING TOOL")
    print(f"Kubeconfig: {args.kubeconfig if args.kubeconfig else 'по умолчанию'}")
    
    # Загрузка kubeconfig
    if not load_kubeconfig(args.kubeconfig):
        sys.exit(1)
    
    # Инициализация клиента
    v1_core = client.CoreV1Api()
    
    # Тест доступа к namespace
    ns_access, target_namespaces = test_namespace_access(v1_core)
    if not ns_access:
        print(f"\n{error_mark()} Критическая ошибка: нет доступа к namespace")
        sys.exit(1)
    
    if not target_namespaces:
        print(f"\n{Colors.YELLOW}Предупреждение: целевые namespace не найдены{Colors.END}")
        print("Создайте namespace с префиксами 'sales-services-' или 'owner-services-' для тестирования")
        sys.exit(0)
    
    # Выполнение тестов
    configmap_results = test_configmap_operations(v1_core, target_namespaces)
    secret_results = test_secret_operations(v1_core, target_namespaces)
    pod_results = test_pod_operations(v1_core, target_namespaces)
    
    # Вывод итоговой таблицы
    print_results_table(target_namespaces, configmap_results, secret_results, pod_results)
    
    print(f"\n{Colors.BOLD}Тестирование завершено!{Colors.END}")
    print(f"Легенда: {success_mark()} - успех, {error_mark()} - ошибка")

if __name__ == "__main__":
    main()
